VERSION 5.00
Begin VB.Form FormTwins 
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Generate Twins"
   ClientHeight    =   6525
   ClientLeft      =   -15
   ClientTop       =   390
   ClientWidth     =   12030
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   435
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   802
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.pdButtonStrip btsOrientation 
      Height          =   1095
      Left            =   6000
      TabIndex        =   2
      Top             =   2040
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1931
      Caption         =   "orientation"
   End
   Begin PhotoDemon.pdCommandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5775
      Width           =   12030
      _ExtentX        =   21220
      _ExtentY        =   1323
   End
   Begin PhotoDemon.pdFxPreviewCtl pdFxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   1
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
      DisableZoomPan  =   -1  'True
   End
End
Attribute VB_Name = "FormTwins"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'"Twin" Filter Interface
'Copyright 2001-2016 by Tanner Helland
'Created: 6/12/01
'Last updated: 24/August/13
'Last update: added command bar
'
'Unoptimized "twin" generator.  Simple 50% alpha blending combined with a flip.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'This routine mirrors and alphablends an image, making it "tilable" or symmetrical
Public Sub GenerateTwins(ByVal tType As Long, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As pdFxPreviewCtl)
   
    If Not toPreview Then Message "Generating image twin..."
    
    'Create a local array and point it at the pixel data of the current image
    Dim dstImageData() As Byte
    Dim dstSA As SAFEARRAY2D
    PrepImageData dstSA, toPreview, dstPic, , , True
    CopyMemory ByVal VarPtrArray(dstImageData()), VarPtr(dstSA), 4
    
    'Create a second local array.  This will contain the a copy of the current image, and we will use it as our source reference
    ' (This is necessary to prevent already-processed pixels from affecting the results of later pixels.)
    Dim srcImageData() As Byte
    Dim srcSA As SAFEARRAY2D
    
    Dim srcDIB As pdDIB
    Set srcDIB = New pdDIB
    srcDIB.CreateFromExistingDIB workingDIB
    
    PrepSafeArray srcSA, srcDIB
    CopyMemory ByVal VarPtrArray(srcImageData()), VarPtr(srcSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim QuickVal As Long, qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'Pre-calculate the largest possible processed x-value
    Dim maxX As Long
    maxX = finalX * qvDepth
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    progBarCheck = FindBestProgBarValue()
            
    'This look-up table will be used for alpha-blending.  It contains the equivalent of any two color values [0,255] added
    ' together and divided by 2.
    Dim hLookup(0 To 510) As Byte
    For x = 0 To 510
        hLookup(x) = x \ 2
    Next x
    
    'Color variables
    Dim r As Long, g As Long, b As Long, a As Long
    Dim r2 As Long, g2 As Long, b2 As Long, a2 As Long
    
    'Loop through each pixel in the image, converting values as we go
    For x = initX To finalX
        QuickVal = x * qvDepth
    For y = initY To finalY
    
        'Grab the current pixel values
        r = srcImageData(QuickVal + 2, y)
        g = srcImageData(QuickVal + 1, y)
        b = srcImageData(QuickVal, y)
        If qvDepth = 4 Then a = srcImageData(QuickVal + 3, y)
        
        'Grab the value of the "second" pixel, whose position will vary depending on the method (vertical or horizontal)
        If tType = 0 Then
            r2 = srcImageData(maxX - QuickVal + 2, y)
            g2 = srcImageData(maxX - QuickVal + 1, y)
            b2 = srcImageData(maxX - QuickVal, y)
            If qvDepth = 4 Then a2 = srcImageData(maxX - QuickVal + 3, y)
        Else
            r2 = srcImageData(QuickVal + 2, finalY - y)
            g2 = srcImageData(QuickVal + 1, finalY - y)
            b2 = srcImageData(QuickVal, finalY - y)
            If qvDepth = 4 Then a2 = srcImageData(QuickVal + 3, finalY - y)
        End If
        
        'Alpha-blend the two pixels using our shortcut look-up table
        dstImageData(QuickVal + 2, y) = hLookup(r + r2)
        dstImageData(QuickVal + 1, y) = hLookup(g + g2)
        dstImageData(QuickVal, y) = hLookup(b + b2)
        
        If qvDepth = 4 Then dstImageData(QuickVal + 3, y) = hLookup(a + a2)
        
    Next y
        If Not toPreview Then
            If (x And progBarCheck) = 0 Then
                If UserPressedESC() Then Exit For
                SetProgBarVal x
            End If
        End If
    Next x
    
    'With our work complete, point both ImageData() arrays away from their DIBs and deallocate them
    CopyMemory ByVal VarPtrArray(srcImageData), 0&, 4
    Erase srcImageData
    
    CopyMemory ByVal VarPtrArray(dstImageData), 0&, 4
    Erase dstImageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    FinalizeImageData toPreview, dstPic, True
        
End Sub

Private Sub btsOrientation_Click(ByVal buttonIndex As Long)
    UpdatePreview
End Sub

Private Sub cmdBar_OKClick()
    Process "Twins", , BuildParams(btsOrientation.ListIndex), UNDO_LAYER
End Sub

Private Sub cmdBar_RequestPreviewUpdate()
    UpdatePreview
End Sub

Private Sub Form_Load()
    
    cmdBar.MarkPreviewStatus False
    
    btsOrientation.AddItem "horizontal", 0
    btsOrientation.AddItem "vertical", 1
    btsOrientation.ListIndex = 0
    
    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
    cmdBar.MarkPreviewStatus True
    UpdatePreview
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

Private Sub UpdatePreview()
    If cmdBar.PreviewsAllowed Then GenerateTwins btsOrientation.ListIndex, True, pdFxPreview
End Sub

'If the user changes the position and/or zoom of the preview viewport, the entire preview must be redrawn.
Private Sub pdFxPreview_ViewportChanged()
    UpdatePreview
End Sub





