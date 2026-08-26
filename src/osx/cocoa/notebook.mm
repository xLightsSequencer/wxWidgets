///////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/cocoa/notebook.mm
// Purpose:     implementation of wxNotebook
// Author:      Stefan Csomor
// Created:     1998-01-01
// Copyright:   (c) Stefan Csomor
// Licence:     wxWindows licence
///////////////////////////////////////////////////////////////////////////////

#include "wx/wxprec.h"

#if wxUSE_NOTEBOOK

#include "wx/notebook.h"

#ifndef WX_PRECOMP
    #include "wx/string.h"
    #include "wx/log.h"
    #include "wx/app.h"
    #include "wx/image.h"
#endif

#include "wx/string.h"
#include "wx/private/bmpbndl.h"
#include "wx/osx/private.h"
#include "wx/osx/private/available.h"

//
// controller
//

@interface wxTabViewController : NSObject <NSTabViewDelegate>
{
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;

@end

@interface wxNSTabView : NSTabView
{
}

@end

@implementation wxTabViewController

- (id) init
{
    self = [super init];
    return self;
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    wxUnusedVar(tabViewItem);
    wxNSTabView* view = (wxNSTabView*) tabView;
    wxWidgetCocoaImpl* viewimpl = (wxWidgetCocoaImpl* ) wxWidgetImpl::FindFromWXWidget( view );

    if ( viewimpl )
    {
        // wxNotebook* wxpeer = (wxNotebook*) viewimpl->GetWXPeer();
    }
    return YES;
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    wxUnusedVar(tabViewItem);
    wxNSTabView* view = (wxNSTabView*) tabView;
    wxWidgetCocoaImpl* viewimpl = (wxWidgetCocoaImpl* ) wxWidgetImpl::FindFromWXWidget( view );
    if ( viewimpl )
    {
        wxNotebook* wxpeer = (wxNotebook*) viewimpl->GetWXPeer();
        wxpeer->OSXHandleClicked(0);
    }
}

@end

@implementation wxNSTabView

+ (void)initialize
{
    static BOOL initialized = NO;
    if (!initialized)
    {
        initialized = YES;

        // On macOS 26 Tahoe, the mere presence of drawRect: in derived class,
        // even if it just calls super's implementation, triggers legacy
        // rendering of NSTabView.
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_VERSION_26_0
        if (WX_IS_MACOS_AVAILABLE(26, 0))
        {
            wxOSXCocoaClassAddWXMethods(self, wxOSXSKIP_DRAW);
        }
        else
#endif
        {
            wxOSXCocoaClassAddWXMethods(self);
        }
    }
}

@end

// ========================================================================
// WXCTabViewImageItem
// ========================================================================
@interface WXCTabViewImageItem : NSTabViewItem
{
    NSImage *m_image;
}
- (id)init;
- (void)dealloc;
- (NSSize)sizeOfLabel:(BOOL)shouldTruncateLabel;
- (void)drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)tabRect;
- (NSImage*)image;
- (void)setImage:(NSImage*)image;
@end // interface WXCTabViewImageItem : NSTabViewItem


@implementation WXCTabViewImageItem : NSTabViewItem
- (id)init
{
    // With 10.12 SDK initWithIdentifier: is declared as taking a non-nil value
    // and while this was fixed in 10.13 by adding the missing "nullable",
    // avoid the annoying warning with 10.12 by explicitly disabling it.
    wxCLANG_WARNING_SUPPRESS(nonnull)

    if (self = [super initWithIdentifier:nil])
    {
        m_image = nil;
    }

    wxCLANG_WARNING_RESTORE(nonnull)

    return self;
}
- (void)dealloc
{
    [m_image release];
    [super dealloc];
}
- (NSSize)sizeOfLabel:(BOOL)shouldTruncateLabel
{
    NSSize labelSize = [super sizeOfLabel:shouldTruncateLabel];
    if(!m_image)
        return labelSize;
    NSSize imageSize = [m_image size];
    // scale image size
    if(imageSize.height > labelSize.height)
    {
        imageSize.width *= labelSize.height/imageSize.height;
        imageSize.height *= labelSize.height/imageSize.height;
        [m_image setSize: imageSize];
    }
    labelSize.width += imageSize.width;
    return labelSize;
}
- (void)drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)tabRect
{
    if(m_image)
    {
        NSSize imageSize = [m_image size];
        NSAffineTransform* imageTransform = [NSAffineTransform transform];
        if( [[self view] isFlipped] )
        {
            [imageTransform translateXBy:tabRect.origin.x yBy:tabRect.origin.y+imageSize.height];
            [imageTransform scaleXBy:1.0 yBy:-1.0];
            [imageTransform concat];
        }
        [m_image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        if( [[self view] isFlipped] )
        {
            [imageTransform invert];
            [imageTransform concat];
        }
        tabRect.size.width -= imageSize.width;
        tabRect.origin.x += imageSize.width;
    }
    [super drawLabel:shouldTruncateLabel inRect:tabRect];
}
- (NSImage*)image
{
    return m_image;
}

- (void)setImage:(NSImage*)image
{
    [image retain];
    [m_image release];
    m_image = image;
    if(!m_image)
        return;
}

@end // implementation WXCTabViewImageItem : NSTabViewItem


class wxCocoaTabView : public wxWidgetCocoaImpl
{
public:
    wxCocoaTabView( wxWindowMac* peer , WXWidget w ) : wxWidgetCocoaImpl(peer, w)
    {
        // NSTabView hands its content rect on to the page views and to the
        // segmented control holding the tabs, so a tab view smaller than its
        // own chrome gives them a negative sized frame. The chrome doesn't
        // change afterwards, so measure it once here, while the tab view is
        // still empty, and never let the frame fall below it. The segmented
        // control is inset inside the content area, hence the extra margin.
        const CGFloat marginForTabs = 4;
        NSTabView* tabview = (NSTabView*) w;
        const NSRect former = [tabview frame];
        const CGFloat probe = 1000;
        [tabview setFrame:NSMakeRect(former.origin.x, former.origin.y, probe, probe)];
        const NSRect content = [tabview contentRect];
        m_chrome = NSMakeSize(probe - content.size.width + marginForTabs,
                              probe - content.size.height + marginForTabs);

        NSRect frame = former;
        frame.size.width = wxMax(frame.size.width, m_chrome.width);
        frame.size.height = wxMax(frame.size.height, m_chrome.height);
        [tabview setFrame:frame];
    }

    void Move( int x, int y, int width, int height ) override
    {
        wxWidgetCocoaImpl::Move(x, y,
                                wxMax(width, (int)m_chrome.width),
                                wxMax(height, (int)m_chrome.height));
    }

    void GetContentArea( int &left , int &top , int &width , int &height ) const override
    {
        wxNSTabView* slf = (wxNSTabView*) m_osxView;
        NSRect r = [slf contentRect];
        left = (int)r.origin.x;
        top = (int)r.origin.y;
        width = wxMax((int)r.size.width, 0);
        height = wxMax((int)r.size.height, 0);
    }

    void SetValue( wxInt32 value ) override
    {
        wxNSTabView* slf = (wxNSTabView*) m_osxView;
        // avoid 'changed' events when setting the tab programmatically
        wxTabViewController* controller = [slf delegate];
        [slf setDelegate:nil];
        if ( value > 0 )
            [slf selectTabViewItemAtIndex:(value-1)];
        [slf setDelegate:controller];
    }

    wxInt32 GetValue() const override
    {
        wxNSTabView* slf = (wxNSTabView*) m_osxView;
        NSTabViewItem* selectedItem = [slf selectedTabViewItem];
        if ( selectedItem == nil )
            return 0;
        else
            return [slf indexOfTabViewItem:selectedItem]+1;
    }

    void SetupTabs( const wxNotebook& notebook) override
    {
        wxNSTabView* slf = (wxNSTabView*) m_osxView;
        int cocoacount = [slf numberOfTabViewItems ];
        // avoid 'changed' events when setting the tab programmatically
        wxTabViewController* controller = [slf delegate];
        [slf setDelegate:nil];

        // Update the existing pages in case their label or image changed.
        const int maximum = notebook.GetPageCount();
        for ( int i = 0; i < wxMin(maximum, cocoacount); ++i )
        {
            SetupTabItem(notebook, i,
                         [(wxNSTabView*) m_osxView tabViewItemAtIndex:i]);

        }

        // Next also add new pages or delete the no more existing ones.
        if ( maximum > cocoacount )
        {
            for ( int i = cocoacount ; i < maximum ; ++i )
            {
                NSTabViewItem* item = [[WXCTabViewImageItem alloc] init];
                SetupTabItem(notebook, i, item);

                [slf addTabViewItem:item];
                [item release];
            }
        }
        else if ( maximum < cocoacount )
        {
            for ( int i = cocoacount -1 ; i >= maximum ; --i )
            {
                NSTabViewItem* item = [(wxNSTabView*) m_osxView tabViewItemAtIndex:i];
                [slf removeTabViewItem:item];
            }
        }
        [slf setDelegate:controller];
    }

    int TabHitTest(const wxPoint & pt, long* flags) override
    {
        int retval = wxNOT_FOUND;

        NSPoint nspt = wxToNSPoint( m_osxView, pt );

        wxNSTabView* slf = (wxNSTabView*) m_osxView;

        NSTabViewItem* hitItem = [slf tabViewItemAtPoint:nspt];

        if (!hitItem) {
            if ( flags )
                *flags = wxBK_HITTEST_NOWHERE;
        } else {
            retval = [slf indexOfTabViewItem:hitItem];
            if ( flags )
                *flags = wxBK_HITTEST_ONLABEL;
        }

        return retval;
    }

private:
    NSSize m_chrome;

    void SetupTabItem(const wxNotebook& notebook, int i, NSTabViewItem* item)
    {
        wxNotebookPage* page = notebook.GetPage(i);
        [item setView:page->GetHandle() ];
        wxCFStringRef cf( wxControl::RemoveMnemonics(notebook.GetPageText(i)) );
        [item setLabel:cf.AsNSString()];

        const wxBitmapBundle bitmap = notebook.GetPageBitmapBundle(i);
        if ( bitmap.IsOk() )
        {
            [(WXCTabViewImageItem*) item setImage: wxOSXGetImageFromBundle(bitmap)];
        }
    }
};


/*
#if 0
    Rect bounds = wxMacGetBoundsForControl( this, pos, size );

    if ( bounds.right <= bounds.left )
        bounds.right = bounds.left + 100;
    if ( bounds.bottom <= bounds.top )
        bounds.bottom = bounds.top + 100;

    UInt16 tabstyle = kControlTabDirectionNorth;
    if ( HasFlag(wxBK_LEFT) )
        tabstyle = kControlTabDirectionWest;
    else if ( HasFlag( wxBK_RIGHT ) )
        tabstyle = kControlTabDirectionEast;
    else if ( HasFlag( wxBK_BOTTOM ) )
        tabstyle = kControlTabDirectionSouth;

    ControlTabSize tabsize;
    switch (GetWindowVariant())
    {
        case wxWINDOW_VARIANT_MINI:
            tabsize = 3 ;
            break;

        case wxWINDOW_VARIANT_SMALL:
            tabsize = kControlTabSizeSmall;
            break;

        default:
            tabsize = kControlTabSizeLarge;
            break;
    }

    m_peer = new wxMacControl( this );
    OSStatus err = CreateTabsControl(
        MAC_WXHWND(parent->MacGetTopLevelWindowRef()), &bounds,
        tabsize, tabstyle, 0, nullptr, GetPeer()->GetControlRefAddr() );
    verify_noerr( err );
#endif
*/
wxWidgetImplType* wxWidgetImpl::CreateTabView( wxWindowMac* wxpeer,
                                    wxWindowMac* WXUNUSED(parent),
                                    wxWindowID WXUNUSED(id),
                                    const wxPoint& pos,
                                    const wxSize& size,
                                    long style,
                                    long WXUNUSED(extraStyle))
{
    static wxTabViewController* controller = nullptr;

    if ( !controller )
        controller =[[wxTabViewController alloc] init];

    NSRect r = wxOSXGetFrameForControl( wxpeer, pos , size ) ;

    NSTabViewType tabstyle = NSTopTabsBezelBorder;
    if ( style & wxBK_LEFT )
        tabstyle = NSLeftTabsBezelBorder;
    else if ( style & wxBK_RIGHT )
        tabstyle = NSRightTabsBezelBorder;
    else if ( style & wxBK_BOTTOM )
        tabstyle = NSBottomTabsBezelBorder;

    wxNSTabView* v = [[wxNSTabView alloc] initWithFrame:r];
    [v setTabViewType:tabstyle];
    wxWidgetCocoaImpl* c = new wxCocoaTabView( wxpeer, v );
    [v setDelegate: controller];
    return c;
}

#endif
