// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "vm/object.h"

#include "vm/hash_table.h"
#include "vm/isolate_reload.h"
#include "vm/log.h"
#include "vm/resolver.h"
#include "vm/symbols.h"

namespace dart {

#ifndef PRODUCT

DECLARE_FLAG(bool, trace_reload);
DECLARE_FLAG(bool, trace_reload_verbose);
DECLARE_FLAG(bool, two_args_smi_icd);


class ObjectReloadUtils : public AllStatic {
  static void DumpLibraryDictionary(const Library& lib) {
    DictionaryIterator it(lib);
    Object& entry = Object::Handle();
    String& name = String::Handle();
    TIR_Print("Dumping dictionary for %s\n", lib.ToCString());
    while (it.HasNext()) {
      entry = it.GetNext();
      name = entry.DictionaryName();
      TIR_Print("%s -> %s\n", name.ToCString(), entry.ToCString());
    }
  }
};


void Function::Reparent(const Class& new_cls) const {
  set_owner(new_cls);
}


void Function::ZeroEdgeCounters() const {
  const Array& saved_ic_data = Array::Handle(ic_data_array());
  if (saved_ic_data.IsNull()) {
    return;
  }
  const intptr_t saved_ic_datalength = saved_ic_data.Length();
  ASSERT(saved_ic_datalength > 0);
  const Array& edge_counters_array =
      Array::Handle(Array::RawCast(saved_ic_data.At(0)));
  ASSERT(!edge_counters_array.IsNull());
  // Fill edge counters array with zeros.
  const Smi& zero = Smi::Handle(Smi::New(0));
  for (intptr_t i = 0; i < edge_counters_array.Length(); i++) {
    edge_counters_array.SetAt(i, zero);
  }
}


void Code::ResetICDatas() const {
  // Iterate over the Code's object pool and reset all ICDatas.
#ifdef TARGET_ARCH_IA32
  // IA32 does not have an object pool, but, we can iterate over all
  // embedded objects by using the variable length data section.
  if (!is_alive()) {
    return;
  }
  const Instructions& instrs = Instructions::Handle(instructions());
  ASSERT(!instrs.IsNull());
  uword base_address = instrs.EntryPoint();
  Object& object = Object::Handle();
  intptr_t offsets_length = pointer_offsets_length();
  const int32_t* offsets = raw_ptr()->data();
  for (intptr_t i = 0; i < offsets_length; i++) {
    int32_t offset = offsets[i];
    RawObject** object_ptr =
        reinterpret_cast<RawObject**>(base_address + offset);
    RawObject* raw_object = *object_ptr;
    if (!raw_object->IsHeapObject()) {
      continue;
    }
    object = raw_object;
    if (object.IsICData()) {
      ICData::Cast(object).Reset();
    }
  }
#else
  const ObjectPool& pool = ObjectPool::Handle(object_pool());
  Object& object = Object::Handle();
  ASSERT(!pool.IsNull());
  for (intptr_t i = 0; i < pool.Length(); i++) {
    ObjectPool::EntryType entry_type = pool.InfoAt(i);
    if (entry_type != ObjectPool::kTaggedObject) {
      continue;
    }
    object = pool.ObjectAt(i);
    if (object.IsICData()) {
      ICData::Cast(object).Reset();
    }
  }
#endif
}


void Class::CopyStaticFieldValues(const Class& old_cls) const {
  // We only update values for non-enum classes.
  const bool update_values = !is_enum_class();

  IsolateReloadContext* reload_context = Isolate::Current()->reload_context();
  ASSERT(reload_context != NULL);

  const Array& old_field_list = Array::Handle(old_cls.fields());
  Field& old_field = Field::Handle();
  String& old_name = String::Handle();

  const Array& field_list = Array::Handle(fields());
  Field& field = Field::Handle();
  String& name = String::Handle();

  Instance& value = Instance::Handle();
  for (intptr_t i = 0; i < field_list.Length(); i++) {
    field = Field::RawCast(field_list.At(i));
    name = field.name();
    if (field.is_static()) {
      // Find the corresponding old field, if it exists, and migrate
      // over the field value.
      for (intptr_t j = 0; j < old_field_list.Length(); j++) {
        old_field = Field::RawCast(old_field_list.At(j));
        old_name = old_field.name();
        if (name.Equals(old_name)) {
          if (update_values) {
            value = old_field.StaticValue();
            field.SetStaticValue(value);
          }
          reload_context->AddStaticFieldMapping(old_field, field);
        }
      }
    }
  }
}


void Class::CopyCanonicalConstants(const Class& old_cls) const {
  if (is_enum_class()) {
    // We do not copy enum classes's canonical constants because we explicitly
    // become the old enum values to the new enum values.
    return;
  }
#if defined(DEBUG)
  {
    // Class has no canonical constants allocated.
    const Array& my_constants = Array::Handle(constants());
    ASSERT(my_constants.Length() == 0);
  }
#endif  // defined(DEBUG).
  // Copy old constants into new class.
  const Array& old_constants = Array::Handle(old_cls.constants());
  if (old_constants.IsNull() || old_constants.Length() == 0) {
    return;
  }
  TIR_Print("Copied %" Pd " canonical constants for class `%s`\n",
            old_constants.Length(),
            ToCString());
  set_constants(old_constants);
}


void Class::CopyCanonicalType(const Class& old_cls) const {
  const Type& old_canonical_type = Type::Handle(old_cls.canonical_type());
  if (old_canonical_type.IsNull()) {
    return;
  }
  set_canonical_type(old_canonical_type);
}


class EnumMapTraits {
 public:
  static bool ReportStats() { return false; }
  static const char* Name() { return "EnumMapTraits"; }

  static bool IsMatch(const Object& a, const Object& b) {
    return a.raw() == b.raw();
  }

  static uword Hash(const Object& obj) {
    ASSERT(obj.IsString());
    return String::Cast(obj).Hash();
  }
};


// Given an old enum class, add become mappings from old values to new values.
// Some notes about how we reload enums below:
//
// When an enum is reloaded the following three things can happen, possibly
// simultaneously.
//
// 1) A new enum value is added.
//   This case is handled automatically.
// 2) Enum values are reordered.
//   We pair old and new enums and the old enums 'become' the new ones so
//   the ordering is always correct (i.e. enum indicies match slots in values
//   array)
// 3) An existing enum value is removed.
//   We leave old enum values that have no mapping to the reloaded class
//   in the heap. This means that if a programmer does the following:
//   enum Foo { A, B }; var x = Foo.A;
//   *reload*
//   enum Foo { B };
//   *reload*
//   enum Foo { A, B }; expect(identical(x, Foo.A));
//   The program will fail because we were not able to pair Foo.A on the second
//   reload.
//
//   Deleted enum values still in the heap continue to function but their
//   index field will not be valid.
void Class::ReplaceEnum(const Class& old_enum) const {
  // We only do this for finalized enum classes.
  ASSERT(is_enum_class());
  ASSERT(old_enum.is_enum_class());
  ASSERT(is_finalized());
  ASSERT(old_enum.is_finalized());

  Thread* thread = Thread::Current();
  Zone* zone = thread->zone();
  IsolateReloadContext* reload_context = Isolate::Current()->reload_context();
  ASSERT(reload_context != NULL);

  Array& enum_fields = Array::Handle(zone);
  Field& field = Field::Handle(zone);
  String& enum_ident = String::Handle();
  Instance& old_enum_value = Instance::Handle(zone);
  Instance& enum_value = Instance::Handle(zone);

  Array& enum_map_storage = Array::Handle(zone,
      HashTables::New<UnorderedHashMap<EnumMapTraits> >(4));
  ASSERT(!enum_map_storage.IsNull());

  TIR_Print("Replacing enum `%s`\n", String::Handle(Name()).ToCString());

  {
    UnorderedHashMap<EnumMapTraits> enum_map(enum_map_storage.raw());
    // Build a map of all enum name -> old enum instance.
    enum_fields = old_enum.fields();
    for (intptr_t i = 0; i < enum_fields.Length(); i++) {
      field = Field::RawCast(enum_fields.At(i));
      enum_ident = field.name();
      if (!field.is_static()) {
        // Enum instances are only held in static fields.
        continue;
      }
      if (enum_ident.Equals(Symbols::Values())) {
        // Non-enum instance.
        continue;
      }
      old_enum_value = field.StaticValue();
      ASSERT(!old_enum_value.IsNull());
      VTIR_Print("Element %s being added to mapping\n", enum_ident.ToCString());
      bool update = enum_map.UpdateOrInsert(enum_ident, old_enum_value);
      VTIR_Print("Element %s added to mapping\n", enum_ident.ToCString());
      ASSERT(!update);
    }
    // The storage given to the map may have been reallocated, remember the new
    // address.
    enum_map_storage = enum_map.Release().raw();
  }

  bool enums_deleted = false;
  {
    UnorderedHashMap<EnumMapTraits> enum_map(enum_map_storage.raw());
    // Add a become mapping from the old instances to the new instances.
    enum_fields = fields();
    for (intptr_t i = 0; i < enum_fields.Length(); i++) {
      field = Field::RawCast(enum_fields.At(i));
      enum_ident = field.name();
      if (!field.is_static()) {
        // Enum instances are only held in static fields.
        continue;
      }
      if (enum_ident.Equals(Symbols::Values())) {
        // Non-enum instance.
        continue;
      }
      enum_value = field.StaticValue();
      ASSERT(!enum_value.IsNull());
      old_enum_value ^= enum_map.GetOrNull(enum_ident);
      if (old_enum_value.IsNull()) {
        VTIR_Print("New element %s was not found in mapping\n",
                   enum_ident.ToCString());
      } else {
        VTIR_Print("Adding element `%s` to become mapping\n",
                   enum_ident.ToCString());
        bool removed = enum_map.Remove(enum_ident);
        ASSERT(removed);
        reload_context->AddEnumBecomeMapping(old_enum_value, enum_value);
      }
    }
    enums_deleted = enum_map.NumOccupied() > 0;
    // The storage given to the map may have been reallocated, remember the new
    // address.
    enum_map_storage = enum_map.Release().raw();
  }

  if (enums_deleted && FLAG_trace_reload_verbose) {
    // TODO(johnmccutchan): Add this to the reload 'notices' list.
    VTIR_Print("The following enum values were deleted and are forever lost in "
               "the heap:\n");
    UnorderedHashMap<EnumMapTraits> enum_map(enum_map_storage.raw());
    UnorderedHashMap<EnumMapTraits>::Iterator it(&enum_map);
    while (it.MoveNext()) {
      const intptr_t entry = it.Current();
      enum_ident = String::RawCast(enum_map.GetKey(entry));
      ASSERT(!enum_ident.IsNull());
    }
    enum_map.Release();
  }
}


void Class::PatchFieldsAndFunctions() const {
  // Move all old functions and fields to a patch class so that they
  // still refer to their original script.
  const PatchClass& patch =
      PatchClass::Handle(PatchClass::New(*this, Script::Handle(script())));
  ASSERT(!patch.IsNull());

  const Array& funcs = Array::Handle(functions());
  Function& func = Function::Handle();
  Object& owner = Object::Handle();
  for (intptr_t i = 0; i < funcs.Length(); i++) {
    func = Function::RawCast(funcs.At(i));
    if ((func.token_pos() == TokenPosition::kMinSource) ||
        func.IsClosureFunction()) {
      // Eval functions do not need to have their script updated.
      //
      // Closure functions refer to the parent's script which we can
      // rely on being updated for us, if necessary.
      continue;
    }

    // If the source for this function is already patched, leave it alone.
    owner = func.RawOwner();
    ASSERT(!owner.IsNull());
    if (!owner.IsPatchClass()) {
      ASSERT(owner.raw() == this->raw());
      func.set_owner(patch);
    }
  }

  const Array& field_list = Array::Handle(fields());
  Field& field = Field::Handle();
  for (intptr_t i = 0; i < field_list.Length(); i++) {
    field = Field::RawCast(field_list.At(i));
    owner = field.RawOwner();
    ASSERT(!owner.IsNull());
    if (!owner.IsPatchClass()) {
      ASSERT(owner.raw() == this->raw());
      field.set_owner(patch);
    }
    field.ForceDynamicGuardedCidAndLength();
  }
}


class EnumClassConflict : public ClassReasonForCancelling {
 public:
  EnumClassConflict(const Class& from, const Class& to)
      : ClassReasonForCancelling(from, to) { }

  RawString* ToString() {
    return String::NewFormatted(
        from_.is_enum_class()
        ? "Enum class cannot be redefined to be a non-enum class: %s"
        : "Class cannot be redefined to be a enum class: %s",
        from_.ToCString());
  }
};


class EnsureFinalizedError : public ClassReasonForCancelling {
 public:
  EnsureFinalizedError(const Class& from, const Class& to, const Error& error)
      : ClassReasonForCancelling(from, to), error_(error) { }

 private:
  const Error& error_;

  RawError* ToError() { return error_.raw(); }
};


class NativeFieldsConflict : public ClassReasonForCancelling {
 public:
  NativeFieldsConflict(const Class& from, const Class& to)
      : ClassReasonForCancelling(from, to) { }

 private:
  RawString* ToString() {
    return String::NewFormatted(
        "Number of native fields changed in %s", from_.ToCString());
  }
};


class TypeParametersChanged : public ClassReasonForCancelling {
 public:
  TypeParametersChanged(const Class& from, const Class& to)
      : ClassReasonForCancelling(from, to) {}

  RawString* ToString() {
    return String::NewFormatted(
        "Limitation: type parameters have changed for %s", from_.ToCString());
  }

  void AppendTo(JSONArray* array) {
    JSONObject jsobj(array);
    jsobj.AddProperty("type", "ReasonForCancellingReload");
    jsobj.AddProperty("kind", "TypeParametersChanged");
    jsobj.AddProperty("class", to_);
    jsobj.AddProperty("message",
                      "Limitation: changing type parameters "
                      "does not work with hot reload.");
  }
};


class PreFinalizedConflict :  public ClassReasonForCancelling {
 public:
  PreFinalizedConflict(const Class& from, const Class& to)
      : ClassReasonForCancelling(from, to) {}

 private:
  RawString* ToString() {
    return String::NewFormatted(
        "Original class ('%s') is prefinalized and replacement class "
        "('%s') is not ",
        from_.ToCString(), to_.ToCString());
  }
};


class InstanceSizeConflict :  public ClassReasonForCancelling {
 public:
  InstanceSizeConflict(const Class& from, const Class& to)
      : ClassReasonForCancelling(from, to) {}

 private:
  RawString* ToString() {
    return String::NewFormatted(
        "Instance size mismatch between '%s' (%" Pd ") and replacement "
        "'%s' ( %" Pd ")",
        from_.ToCString(),
        from_.instance_size(),
        to_.ToCString(),
        to_.instance_size());
  }
};


class UnimplementedDeferredLibrary : public ReasonForCancelling {
 public:
  UnimplementedDeferredLibrary(const Library& from,
                               const Library& to,
                               const String& name)
      : ReasonForCancelling(), from_(from), to_(to), name_(name) {}

 private:
  const Library& from_;
  const Library& to_;
  const String& name_;

  RawString* ToString() {
    const String& lib_url = String::Handle(to_.url());
    from_.ToCString();
    return String::NewFormatted(
        "Reloading support for deferred loading has not yet been implemented:"
        " library '%s' has deferred import '%s'",
        lib_url.ToCString(), name_.ToCString());
  }
};


// This is executed before interating over the instances.
void Class::CheckReload(const Class& replacement,
                        IsolateReloadContext* context) const {
  ASSERT(IsolateReloadContext::IsSameClass(*this, replacement));

  // Class cannot change enum property.
  if (is_enum_class() != replacement.is_enum_class()) {
    context->AddReasonForCancelling(
        new EnumClassConflict(*this, replacement));
    return;
  }

  if (is_finalized()) {
    // Ensure the replacement class is also finalized.
    const Error& error =
        Error::Handle(replacement.EnsureIsFinalized(Thread::Current()));
    if (!error.IsNull()) {
      context->AddReasonForCancelling(
          new EnsureFinalizedError(*this, replacement, error));
      return;  // No reason to check other properties.
    }
    TIR_Print("Finalized replacement class for %s\n", ToCString());
  }

  // Native field count cannot change.
  if (num_native_fields() != replacement.num_native_fields()) {
      context->AddReasonForCancelling(
          new NativeFieldsConflict(*this, replacement));
      return;
  }

  // Just checking.
  ASSERT(is_enum_class() == replacement.is_enum_class());
  ASSERT(num_native_fields() == replacement.num_native_fields());

  if (is_finalized()) {
    if (!CanReloadFinalized(replacement, context)) return;
  }
  if (is_prefinalized()) {
    if (!CanReloadPreFinalized(replacement, context)) return;
  }
  ASSERT(is_finalized() == replacement.is_finalized());
  TIR_Print("Class `%s` can be reloaded (%" Pd " and %" Pd ")\n",
            ToCString(), id(), replacement.id());
}



bool Class::RequiresInstanceMorphing(const Class& replacement) const {
  // Get the field maps for both classes. These field maps walk the class
  // hierarchy.
  const Array& fields = Array::Handle(OffsetToFieldMap());
  const Array& replacement_fields
      = Array::Handle(replacement.OffsetToFieldMap());

  // Check that the size of the instance is the same.
  if (fields.Length() != replacement_fields.Length()) return true;

  // Check that we have the same next field offset. This check is not
  // redundant with the one above because the instance OffsetToFieldMap
  // array length is based on the instance size (which may be aligned up).
  if (next_field_offset() != replacement.next_field_offset()) return true;

  // Verify that field names / offsets match across the entire hierarchy.
  Field& field = Field::Handle();
  String& field_name = String::Handle();
  Field& replacement_field = Field::Handle();
  String& replacement_field_name = String::Handle();

  for (intptr_t i = 0; i < fields.Length(); i++) {
    if (fields.At(i) == Field::null()) {
      ASSERT(replacement_fields.At(i) == Field::null());
      continue;
    }
    field = Field::RawCast(fields.At(i));
    replacement_field = Field::RawCast(replacement_fields.At(i));
    field_name = field.name();
    replacement_field_name = replacement_field.name();
    if (!field_name.Equals(replacement_field_name)) return true;
  }
  return false;
}


bool Class::CanReloadFinalized(const Class& replacement,
                               IsolateReloadContext* context) const {
  // Make sure the declaration types matches for the two classes.
  // ex. class A<int,B> {} cannot be replace with class A<B> {}.

  const AbstractType& dt = AbstractType::Handle(DeclarationType());
  const AbstractType& replacement_dt =
      AbstractType::Handle(replacement.DeclarationType());
  if (!dt.Equals(replacement_dt)) {
    context->AddReasonForCancelling(
        new TypeParametersChanged(*this, replacement));
    return false;
  }
  if (RequiresInstanceMorphing(replacement)) {
    context->AddInstanceMorpher(new InstanceMorpher(*this, replacement));
  }
  return true;
}


bool Class::CanReloadPreFinalized(const Class& replacement,
                                  IsolateReloadContext* context) const {
  // The replacement class must also prefinalized.
  if (!replacement.is_prefinalized()) {
      context->AddReasonForCancelling(
          new PreFinalizedConflict(*this, replacement));
      return false;
  }
  // Check the instance sizes are equal.
  if (instance_size() != replacement.instance_size()) {
      context->AddReasonForCancelling(
          new InstanceSizeConflict(*this, replacement));
      return false;
  }
  return true;
}


void Library::CheckReload(const Library& replacement,
                          IsolateReloadContext* context) const {
  // TODO(26878): If the replacement library uses deferred loading,
  // reject it.  We do not yet support reloading deferred libraries.
  LibraryPrefix& prefix = LibraryPrefix::Handle();
  LibraryPrefixIterator it(replacement);
  while (it.HasNext()) {
    prefix = it.GetNext();
    if (prefix.is_deferred_load()) {
      const String& prefix_name = String::Handle(prefix.name());
      context->AddReasonForCancelling(
          new UnimplementedDeferredLibrary(*this, replacement, prefix_name));
      return;
    }
  }
}


static const Function* static_call_target = NULL;


void ICData::Reset() const {
  if (is_static_call()) {
    const Function& old_target = Function::Handle(GetTargetAt(0));
    if (old_target.IsNull()) {
      FATAL("old_target is NULL.\n");
    }
    static_call_target = &old_target;

    const String& selector = String::Handle(old_target.name());
    Function& new_target = Function::Handle();
    if (!old_target.is_static()) {
      if (old_target.kind() == RawFunction::kConstructor) {
        return;  // Super constructor call.
      }
      Function& caller = Function::Handle();
      caller ^= Owner();
      ASSERT(!caller.is_static());
      Class& cls = Class::Handle(caller.Owner());
      if (cls.raw() == old_target.Owner()) {
        // Dispatcher.
        if (caller.IsImplicitClosureFunction()) {
          return;  // Tear-off.
        }
        if (caller.kind() == RawFunction::kNoSuchMethodDispatcher) {
          // TODO(rmacnak): noSuchMethod might have been redefined.
          return;
        }
        const Function& caller_parent =
            Function::Handle(caller.parent_function());
        if (!caller_parent.IsNull()) {
          if (caller_parent.kind() == RawFunction::kInvokeFieldDispatcher) {
            return;  // Call-through-getter.
          }
        }
        FATAL2("Unexpected dispatcher-like call site: %s from %s\n",
               selector.ToCString(), caller.ToQualifiedCString());
      }
      // Super call.
      cls = cls.SuperClass();
      while (!cls.IsNull()) {
        // TODO(rmacnak): Should use Resolver::ResolveDynamicAnyArgs to handle
        // method-extractors and call-through-getters, but we're in a no
        // safepoint scope here.
        new_target = cls.LookupDynamicFunction(selector);
        if (!new_target.IsNull()) {
          break;
        }
        cls = cls.SuperClass();
      }
    } else {
      // This can be incorrect if the call site was an unqualified invocation.
      const Class& cls = Class::Handle(old_target.Owner());
      new_target = cls.LookupStaticFunction(selector);
    }

    const Array& args_desc_array = Array::Handle(arguments_descriptor());
    ArgumentsDescriptor args_desc(args_desc_array);
    if (new_target.IsNull() ||
        !new_target.AreValidArguments(args_desc, NULL)) {
      // TODO(rmacnak): Patch to a NSME stub.
      VTIR_Print("Cannot rebind static call to %s from %s\n",
                 old_target.ToCString(),
                 Object::Handle(Owner()).ToCString());
      return;
    }
    ClearAndSetStaticTarget(new_target);
  } else {
    ClearWithSentinel();
  }
}

#endif  // !PRODUCT

}   // namespace dart.
