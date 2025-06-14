/////////////////////////////////////////////////////////////////////////////
// Name:        wx/object.h
// Purpose:     wxObject class, plus run-time type information macros
// Author:      Julian Smart
// Modified by: Ron Lee
// Created:     01/02/97
// Copyright:   (c) 1997 Julian Smart
//              (c) 2001 Ron Lee <ron@debian.org>
// Licence:     wxWindows licence
/////////////////////////////////////////////////////////////////////////////

#ifndef _WX_OBJECTH__
#define _WX_OBJECTH__

// ----------------------------------------------------------------------------
// headers
// ----------------------------------------------------------------------------

// This really shouldn't be done here, but keep including this header for
// compatibility as it used to be included from here in the previous versions
// of wx and a lot of code would be broken by removing it.
#ifndef WXBUILDING
    #include "wx/string.h"
#endif
#include <atomic>
#include "wx/memory.h"

// based on the value of wxUSE_EXTENDED_RTTI symbol,
// only one of the RTTI system will be compiled:
// - the "old" one (defined by rtti.h) or
// - the "new" one (defined by xti.h)
#include "wx/xti.h"
#include "wx/rtti.h"

#define wxIMPLEMENT_CLASS(name, basename)                                     \
    wxIMPLEMENT_ABSTRACT_CLASS(name, basename)

#define wxIMPLEMENT_CLASS2(name, basename1, basename2)                        \
    wxIMPLEMENT_ABSTRACT_CLASS2(name, basename1, basename2)

// -----------------------------------
// for pluggable classes
// -----------------------------------

    // NOTE: this should probably be the very first statement
    //       in the class declaration so wxPluginSentinel is
    //       the first member initialised and the last destroyed.

// _DECLARE_DL_SENTINEL(name) wxPluginSentinel m_pluginsentinel;

#if wxUSE_NESTED_CLASSES

#define _DECLARE_DL_SENTINEL(name, exportdecl)  \
class exportdecl name##PluginSentinel {         \
private:                                        \
    static const wxString sm_className;         \
public:                                         \
    name##PluginSentinel();                     \
    ~name##PluginSentinel();                    \
};                                              \
name##PluginSentinel  m_pluginsentinel

#define _IMPLEMENT_DL_SENTINEL(name)                                \
 const wxString name::name##PluginSentinel::sm_className(#name);    \
 name::name##PluginSentinel::name##PluginSentinel() {               \
    wxPluginLibrary *e = (wxPluginLibrary*) wxPluginLibrary::ms_classes.Get(#name);   \
    if( e != 0 ) { e->RefObj(); }                                      \
 }                                                                  \
 name::name##PluginSentinel::~name##PluginSentinel() {            \
    wxPluginLibrary *e = (wxPluginLibrary*) wxPluginLibrary::ms_classes.Get(#name);   \
    if( e != 0 ) { e->UnrefObj(); }                                 \
 }
#else

#define _DECLARE_DL_SENTINEL(name)
#define _IMPLEMENT_DL_SENTINEL(name)

#endif  // wxUSE_NESTED_CLASSES

#define wxDECLARE_PLUGGABLE_CLASS(name) \
 wxDECLARE_DYNAMIC_CLASS(name); _DECLARE_DL_SENTINEL(name, WXDLLIMPEXP_CORE)
#define wxDECLARE_ABSTRACT_PLUGGABLE_CLASS(name)  \
 wxDECLARE_ABSTRACT_CLASS(name); _DECLARE_DL_SENTINEL(name, WXDLLIMPEXP_CORE)

#define wxDECLARE_USER_EXPORTED_PLUGGABLE_CLASS(name, usergoo) \
 wxDECLARE_DYNAMIC_CLASS(name); _DECLARE_DL_SENTINEL(name, usergoo)
#define wxDECLARE_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS(name, usergoo)  \
 wxDECLARE_ABSTRACT_CLASS(name); _DECLARE_DL_SENTINEL(name, usergoo)

#define wxIMPLEMENT_PLUGGABLE_CLASS(name, basename) \
 wxIMPLEMENT_DYNAMIC_CLASS(name, basename) _IMPLEMENT_DL_SENTINEL(name)
#define wxIMPLEMENT_PLUGGABLE_CLASS2(name, basename1, basename2)  \
 wxIMPLEMENT_DYNAMIC_CLASS2(name, basename1, basename2) _IMPLEMENT_DL_SENTINEL(name)
#define wxIMPLEMENT_ABSTRACT_PLUGGABLE_CLASS(name, basename) \
 wxIMPLEMENT_ABSTRACT_CLASS(name, basename) _IMPLEMENT_DL_SENTINEL(name)
#define wxIMPLEMENT_ABSTRACT_PLUGGABLE_CLASS2(name, basename1, basename2)  \
 wxIMPLEMENT_ABSTRACT_CLASS2(name, basename1, basename2) _IMPLEMENT_DL_SENTINEL(name)

#define wxIMPLEMENT_USER_EXPORTED_PLUGGABLE_CLASS(name, basename) \
 wxIMPLEMENT_PLUGGABLE_CLASS(name, basename)
#define wxIMPLEMENT_USER_EXPORTED_PLUGGABLE_CLASS2(name, basename1, basename2)  \
 wxIMPLEMENT_PLUGGABLE_CLASS2(name, basename1, basename2)
#define wxIMPLEMENT_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS(name, basename) \
 wxIMPLEMENT_ABSTRACT_PLUGGABLE_CLASS(name, basename)
#define wxIMPLEMENT_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS2(name, basename1, basename2)  \
 wxIMPLEMENT_ABSTRACT_PLUGGABLE_CLASS2(name, basename1, basename2)

#define wxCLASSINFO(name) (&name::ms_classInfo)

#define wxIS_KIND_OF(obj, className) obj->IsKindOf(&className::ms_classInfo)

// Just seems a bit nicer-looking (pretend it's not a macro)
#define wxIsKindOf(obj, className) obj->IsKindOf(&className::ms_classInfo)

// this cast does some more checks at compile time as it uses static_cast
// internally
//
// note that it still has different semantics from dynamic_cast<> and so can't
// be replaced by it as long as there are any compilers not supporting it
#define wxDynamicCast(obj, className) \
    (static_cast<className*>(wxCheckDynamicCast( \
        const_cast<wxObject *>(static_cast<const wxObject *>(obj)), \
        &className::ms_classInfo)))

// The 'this' pointer is always true, so use this version
// to cast the this pointer and avoid compiler warnings.
#define wxDynamicCastThis(className) \
     (IsKindOf(&className::ms_classInfo) ? (className*)this : nullptr)

template <class T>
inline T *wxCheckCast(const void *ptr)
{
    wxASSERT_MSG( wxDynamicCast(ptr, T), "wxStaticCast() used incorrectly" );
    return const_cast<T *>(static_cast<const T *>(ptr));
}

#define wxStaticCast(obj, className) wxCheckCast<className>(obj)

// ----------------------------------------------------------------------------
// Compatibility macro aliases DECLARE group
// ----------------------------------------------------------------------------
// deprecated variants _not_ requiring a semicolon after them and without wx prefix.
// (note that also some wx-prefixed macro do _not_ require a semicolon because
// it's not always possible to force the compiler to require it)

#define DECLARE_ABSTRACT_CLASS(n)                                   wxDECLARE_ABSTRACT_CLASS(n);
#define DECLARE_DYNAMIC_CLASS_NO_ASSIGN(n)                          wxDECLARE_DYNAMIC_CLASS_NO_ASSIGN(n);
#define DECLARE_DYNAMIC_CLASS_NO_COPY(n)                            wxDECLARE_DYNAMIC_CLASS_NO_COPY(n);
#define DECLARE_DYNAMIC_CLASS(n)                                    wxDECLARE_DYNAMIC_CLASS(n);
#define DECLARE_CLASS(n)                                            wxDECLARE_CLASS(n);

#define DECLARE_PLUGGABLE_CLASS(n)                                  wxDECLARE_PLUGGABLE_CLASS(n);
#define DECLARE_ABSTRACT_PLUGGABLE_CLASS(n)                         wxDECLARE_ABSTRACT_PLUGGABLE_CLASS(n);
#define DECLARE_USER_EXPORTED_PLUGGABLE_CLASS(n,u)                  wxDECLARE_USER_EXPORTED_PLUGGABLE_CLASS(n,u);
#define DECLARE_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS(n,u)         wxDECLARE_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS(n,u);

// ----------------------------------------------------------------------------
// wxRefCounter: ref counted data "manager"
// ----------------------------------------------------------------------------

class WXDLLIMPEXP_BASE wxRefCounter
{
public:
    wxRefCounter() : m_count(1) { }

    int GetRefCount() const { return m_count; }

    void IncRef() { m_count++; }
    void DecRef();

protected:
    // this object should never be destroyed directly but only as a
    // result of a DecRef() call:
    virtual ~wxRefCounter() = default;

private:
    // our refcount:
    std::atomic_int m_count;

    // It doesn't make sense to copy the reference counted objects, a new ref
    // counter should be created for a new object instead and compilation
    // errors in the code using wxRefCounter due to the lack of copy ctor often
    // indicate a problem, e.g. a forgotten copy ctor implementation somewhere.
    wxDECLARE_NO_COPY_CLASS(wxRefCounter);
};

// ----------------------------------------------------------------------------
// wxObjectRefData: ref counted data meant to be stored in wxObject
// ----------------------------------------------------------------------------

typedef wxRefCounter wxObjectRefData;

// ----------------------------------------------------------------------------
// wxObjectDataPtr: helper class to avoid memleaks because of missing calls
//                  to wxObjectRefData::DecRef
// ----------------------------------------------------------------------------

template <class T>
class wxObjectDataPtr
{
public:
    typedef T element_type;

    explicit wxObjectDataPtr(T *ptr = nullptr) : m_ptr(ptr) {}

    // copy ctor
    wxObjectDataPtr(const wxObjectDataPtr<T> &tocopy)
        : m_ptr(tocopy.m_ptr)
    {
        if (m_ptr)
            m_ptr->IncRef();
    }

    // generalized copy ctor: U must be convertible to T
    template <typename U>
    wxObjectDataPtr(const wxObjectDataPtr<U> &tocopy)
        : m_ptr(tocopy.get())
    {
        if (m_ptr)
            m_ptr->IncRef();
    }

    ~wxObjectDataPtr()
    {
        if (m_ptr)
            m_ptr->DecRef();
    }

    T *get() const { return m_ptr; }

    bool operator==(const wxObjectDataPtr<T>& other) const
    {
        return m_ptr == other.m_ptr;
    }

    bool operator!=(const wxObjectDataPtr<T>& other) const
    {
        return !(*this == other);
    }

    // test for pointer validity: defining conversion to unspecified_bool_type
    // and not more obvious bool to avoid implicit conversions to integer types
    typedef T *(wxObjectDataPtr<T>::*unspecified_bool_type)() const;
    operator unspecified_bool_type() const
    {
        return m_ptr ? &wxObjectDataPtr<T>::get : nullptr;
    }

    T& operator*() const
    {
        wxASSERT(m_ptr != nullptr);
        return *(m_ptr);
    }

    T *operator->() const
    {
        wxASSERT(m_ptr != nullptr);
        return get();
    }

    void reset(T *ptr)
    {
        if (m_ptr)
            m_ptr->DecRef();
        m_ptr = ptr;
    }

    T* release()
    {
        T* const ptr = m_ptr;
        m_ptr = nullptr;
        return ptr;
    }

    wxObjectDataPtr& operator=(const wxObjectDataPtr &tocopy)
    {
        // Take care to increment the reference first to ensure correct
        // behaviour in case of self-assignment.
        T* const ptr = tocopy.m_ptr;
        if (ptr)
            ptr->IncRef();
        if (m_ptr)
            m_ptr->DecRef();
        m_ptr = ptr;
        return *this;
    }

    template <typename U>
    wxObjectDataPtr& operator=(const wxObjectDataPtr<U> &tocopy)
    {
        T* const ptr = tocopy.get();
        if (ptr)
            ptr->IncRef();
        if (m_ptr)
            m_ptr->DecRef();
        m_ptr = ptr;
        return *this;
    }

    wxObjectDataPtr& operator=(T *ptr)
    {
        if (m_ptr)
            m_ptr->DecRef();
        m_ptr = ptr;
        return *this;
    }

private:
    T *m_ptr;
};

// ----------------------------------------------------------------------------
// wxObject: the root class of wxWidgets object hierarchy
// ----------------------------------------------------------------------------

class WXDLLIMPEXP_BASE wxObject
{
#if wxUSE_EXTENDED_RTTI
    wxDECLARE_DYNAMIC_CLASS(wxObject);
#endif

public:
    wxObject() { m_refData = nullptr; }
    virtual ~wxObject() { UnRef(); }

    wxObject(const wxObject& other)
    {
         m_refData = other.m_refData;
         if (m_refData)
             m_refData->IncRef();
    }

    wxObject& operator=(const wxObject& other)
    {
        if ( this != &other )
        {
            Ref(other);
        }
        return *this;
    }

    bool IsKindOf(const wxClassInfo *info) const;

    // Turn on the correct set of new and delete operators

#ifdef _WX_WANT_NEW_SIZET_WXCHAR_INT
    void *operator new ( size_t size, const wxChar *fileName = nullptr, int lineNum = 0 );
#endif

#ifdef _WX_WANT_DELETE_VOID
    void operator delete ( void * buf );
#endif

#ifdef _WX_WANT_DELETE_VOID_WXCHAR_INT
    void operator delete ( void *buf, const wxChar*, int );
#endif

#ifdef _WX_WANT_ARRAY_NEW_SIZET_WXCHAR_INT
    void *operator new[] ( size_t size, const wxChar *fileName = nullptr, int lineNum = 0 );
#endif

#ifdef _WX_WANT_ARRAY_DELETE_VOID
    void operator delete[] ( void *buf );
#endif

#ifdef _WX_WANT_ARRAY_DELETE_VOID_WXCHAR_INT
    void operator delete[] (void* buf, const wxChar*, int );
#endif

    // ref counted data handling methods

    // get/set
    wxObjectRefData *GetRefData() const { return m_refData; }
    void SetRefData(wxObjectRefData *data) { m_refData = data; }

    // make a 'clone' of the object
    void Ref(const wxObject& clone);

    // destroy a reference
    void UnRef();

    // Make sure this object has only one reference
    void UnShare() { AllocExclusive(); }

    // check if this object references the same data as the other one
    bool IsSameAs(const wxObject& o) const { return m_refData == o.m_refData; }

#if !wxUSE_EXTENDED_RTTI
    virtual wxClassInfo* GetClassInfo() const;

    // RTTI information, usually declared by wxDECLARE_DYNAMIC_CLASS() or
    // similar, but done manually for the hierarchy root. Note that it's public
    // for compatibility reasons, but shouldn't be accessed directly.
    static wxClassInfo ms_classInfo;
#endif

protected:
    // ensure that our data is not shared with anybody else: if we have no
    // data, it is created using CreateRefData() below, if we have shared data
    // it is copied using CloneRefData(), otherwise nothing is done
    void AllocExclusive();

    // both methods must be implemented if AllocExclusive() is used, not pure
    // virtual only because of the backwards compatibility reasons

    // create a new m_refData
    virtual wxObjectRefData *CreateRefData() const;

    // create a new m_refData initialized with the given one
    wxNODISCARD virtual wxObjectRefData *CloneRefData(const wxObjectRefData *data) const;

    wxObjectRefData *m_refData;
};

inline wxObject *wxCheckDynamicCast(wxObject *obj, wxClassInfo *classInfo)
{
    return obj && obj->GetClassInfo()->IsKindOf(classInfo) ? obj : nullptr;
}

#include "wx/xti2.h"

// ----------------------------------------------------------------------------
// Compatibility macro aliases IMPLEMENT group
// ----------------------------------------------------------------------------

// deprecated variants _not_ requiring a semicolon after them and without wx prefix.
// (note that also some wx-prefixed macro do _not_ require a semicolon because
// it's not always possible to force the compiler to require it)

#define IMPLEMENT_DYNAMIC_CLASS(n,b)                                wxIMPLEMENT_DYNAMIC_CLASS(n,b)
#define IMPLEMENT_DYNAMIC_CLASS2(n,b1,b2)                           wxIMPLEMENT_DYNAMIC_CLASS2(n,b1,b2)
#define IMPLEMENT_ABSTRACT_CLASS(n,b)                               wxIMPLEMENT_ABSTRACT_CLASS(n,b)
#define IMPLEMENT_ABSTRACT_CLASS2(n,b1,b2)                          wxIMPLEMENT_ABSTRACT_CLASS2(n,b1,b2)
#define IMPLEMENT_CLASS(n,b)                                        wxIMPLEMENT_CLASS(n,b)
#define IMPLEMENT_CLASS2(n,b1,b2)                                   wxIMPLEMENT_CLASS2(n,b1,b2)

#define IMPLEMENT_PLUGGABLE_CLASS(n,b)                              wxIMPLEMENT_PLUGGABLE_CLASS(n,b)
#define IMPLEMENT_PLUGGABLE_CLASS2(n,b,b2)                          wxIMPLEMENT_PLUGGABLE_CLASS2(n,b,b2)
#define IMPLEMENT_ABSTRACT_PLUGGABLE_CLASS(n,b)                     wxIMPLEMENT_ABSTRACT_PLUGGABLE_CLASS(n,b)
#define IMPLEMENT_ABSTRACT_PLUGGABLE_CLASS2(n,b,b2)                 wxIMPLEMENT_ABSTRACT_PLUGGABLE_CLASS2(n,b,b2)
#define IMPLEMENT_USER_EXPORTED_PLUGGABLE_CLASS(n,b)                wxIMPLEMENT_USER_EXPORTED_PLUGGABLE_CLASS(n,b)
#define IMPLEMENT_USER_EXPORTED_PLUGGABLE_CLASS2(n,b,b2)            wxIMPLEMENT_USER_EXPORTED_PLUGGABLE_CLASS2(n,b,b2)
#define IMPLEMENT_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS(n,b)       wxIMPLEMENT_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS(n,b)
#define IMPLEMENT_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS2(n,b,b2)   wxIMPLEMENT_USER_EXPORTED_ABSTRACT_PLUGGABLE_CLASS2(n,b,b2)

#define CLASSINFO(n)                                wxCLASSINFO(n)

#endif // _WX_OBJECTH__
