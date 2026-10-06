/////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/carbon/colordlgosx.mm
// Purpose:     wxColourDialog class. NOTE: you can use the generic class
//              if you wish, instead of implementing this.
// Author:      Ryan Norton
// Created:     2004-11-16
// Copyright:   (c) Ryan Norton
// Licence:       wxWindows licence
/////////////////////////////////////////////////////////////////////////////

// ===========================================================================
// declarations
// ===========================================================================

// ---------------------------------------------------------------------------
// headers
// ---------------------------------------------------------------------------

#include "wx/wxprec.h"

#include "wx/colordlg.h"
#include "wx/fontdlg.h"
#include "wx/modalhook.h"
#include "wx/math.h"
#include "wx/utils.h"

// ============================================================================
// implementation
// ============================================================================

//Mac OSX 10.2+ only
#if USE_NATIVE_FONT_DIALOG_FOR_MACOSX && wxUSE_COLOURDLG

wxIMPLEMENT_DYNAMIC_CLASS(wxColourDialog, wxDialog);

#include "wx/osx/private.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// xLights local patch: convert explicitly to Generic RGB (matching the space
// Create() opens the panel in) and keep plain channel values, so the result
// doesn't depend on which colour space the user left the panel's sliders in.
static wxColour wxColourFromPanelColour(NSColor* colour)
{
    NSColor* generic = [colour colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    if ( !generic )
        return wxColour(colour);

    auto channel = [](CGFloat v) { return (unsigned char)wxRound(wxClip(v, 0.0, 1.0) * 255.0); };
    return wxColour(channel([generic redComponent]),
                    channel([generic greenComponent]),
                    channel([generic blueComponent]),
                    channel([generic alphaComponent]));
}

// ---------------------------------------------------------------------------
// wxCPWCDelegate - Window Closed delegate
// ---------------------------------------------------------------------------

@interface wxCPWCDelegate : NSObject <NSWindowDelegate>
{
    bool m_bIsClosed;
    wxColourDialog* m_dialog;
}

// Delegate methods
- (id)initWithDialog:(wxColourDialog*)dialog;
- (BOOL)windowShouldClose:(id)sender;
- (BOOL)isClosed;
- (void)colourChanged:(id)sender;
@end // interface wxNSFontPanelDelegate : NSObject

@implementation wxCPWCDelegate : NSObject

- (id)initWithDialog:(wxColourDialog*)dialog
{
    if ( self = [super init] )
    {
        m_bIsClosed = false;
        m_dialog = dialog;
    }
    return self;
}

// xLights local patch: the panel's action fires as the user drags, so
// forward it as wxEVT_COLOUR_CHANGED like wxMSW does, letting callers
// preview the colour live while the panel is still open.
- (void)colourChanged:(id)sender
{
    wxColourDialogEvent event(wxEVT_COLOUR_CHANGED, m_dialog,
                              wxColourFromPanelColour([(NSColorPanel*)sender color]));
    m_dialog->ProcessWindowEvent(event);
}

// The panel runs in a modal session, during which NSApp drops actions sent
// to targets that don't opt in.
- (BOOL)worksWhenModal
{
    return YES;
}

- (BOOL)windowShouldClose:(id)sender
{
    wxUnusedVar(sender);

    m_bIsClosed = true;

    [NSApp abortModal];
    [NSApp stopModal];
    return YES;
}

- (BOOL)isClosed
{
    return m_bIsClosed;
}

@end // wxNSFontPanelDelegate

/*
 * wxColourDialog
 */

wxColourDialog::wxColourDialog()
{
    m_dialogParent = nullptr;
}

wxColourDialog::wxColourDialog(wxWindow *parent, const wxColourData *data)
{
    Create(parent, data);
}

bool wxColourDialog::Create(wxWindow *parent, const wxColourData *data)
{
    m_dialogParent = parent;

    if (data)
        m_colourData = *data;

    //autorelease pool - req'd for carbon
    NSAutoreleasePool *thePool;
    thePool = [[NSAutoreleasePool alloc] init];

    [[NSColorPanel sharedColorPanel] setShowsAlpha:m_colourData.GetChooseAlpha() ? YES : NO];
    if(m_colourData.GetColour().IsOk())
    {
        // xLights local patch: wxColour(r,g,b) is backed by an sRGB CGColor
        // (wxMacGetGenericRGBColorSpace() returns sRGB), but the channel
        // accessors read NSColors back in NSCalibratedRGBColorSpace, i.e.
        // Generic RGB. Handing the panel the native colour therefore opened it
        // in sRGB and every OK converted the values (255,128,0 came back as
        // 252,106,8). Give the panel the channel values in Generic RGB so it
        // opens there and the round trip is exact.
        const wxColour& c = m_colourData.GetColour();
        [[NSColorPanel sharedColorPanel] setColor:[NSColor colorWithCalibratedRed:c.Red() / 255.0
                                                                            green:c.Green() / 255.0
                                                                             blue:c.Blue() / 255.0
                                                                            alpha:c.Alpha() / 255.0]];
    }
    else
        [[NSColorPanel sharedColorPanel] setColor:[NSColor blackColor]];

    //We're done - free up the pool
    [thePool release];

    return true;
}
int wxColourDialog::ShowModal()
{
    WX_HOOK_MODAL_DIALOG();

    //Start the pool.  Required for carbon interaction
    //(For those curious, the only thing that happens
    //if you don't do this is a bunch of error
    //messages about leaks on the console,
    //with no windows shown or anything).
    NSAutoreleasePool *thePool;
    thePool = [[NSAutoreleasePool alloc] init];

    //Get the shared color and font panel
    NSColorPanel* theColorPanel = [NSColorPanel sharedColorPanel];

    //Create and assign the delegates (cocoa event handlers) so
    //we can tell if a window has closed/open or not
    wxCPWCDelegate* theCPDelegate = [[wxCPWCDelegate alloc] initWithDialog:this];
    [theColorPanel setDelegate:theCPDelegate];
    [theColorPanel setTarget:theCPDelegate];
    [theColorPanel setAction:@selector(colourChanged:)];
    [theColorPanel setContinuous:YES];

            //
            // Start the color panel modal loop
            //
            OSXBeginModalDialog();
            NSModalSession session = [NSApp beginModalSessionForWindow:theColorPanel];
            for (;;)
            {
                [NSApp runModalSession:session];

                //If the color panel is closed, return the font panel modal loop
                if ([theCPDelegate isClosed])
                    break;
            }
            [NSApp endModalSession:session];
            OSXEndModalDialog();

    //free up the memory for the delegates - we don't need them anymore
    [theColorPanel setTarget:nil];
    [theColorPanel setAction:nil];
    [theColorPanel setDelegate:nil];
    [theCPDelegate release];

    //Get the shared color panel along with the chosen color and set the chosen color
    m_colourData.GetColour() = wxColourFromPanelColour([theColorPanel color]);

    //Release the pool, we're done :)
    [thePool release];

    //Return ID_OK - there are no "apply" buttons or the like
    //on either the font or color panel
    return wxID_OK;
}

#endif //use native font dialog

