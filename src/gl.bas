Attribute VB_Name = "GLMd"

Public Sub ReSizeGLScene(ByVal Width As GLsizei, ByVal Height As GLsizei)
    If Height = 0 Then Height = 1
    If Width = 0 Then Width = 1
    
    glViewport 0, 150, Width, Height - 150
    glMatrixMode mmProjection
    glLoadIdentity

    glOrtho 0#, Width, Height - 150, 0#, -1, 1

    glMatrixMode mmModelView
    glLoadIdentity
    
    RenderTicks     ' Regen ticks
End Sub

Public Sub InitGL()
    glShadeModel smFlat

    glLineWidth 1

    glShadeModel GL_SMOOTH

    glClearDepth 1#
    glHint GL_LINE_SMOOTH_HINT, GL_NICEST
    glEnable GL_LINE_SMOOTH
    
    glEnable GL_BLEND
End Sub

Public Sub KillGLWindow()
    If hrc Then
        If wglMakeCurrent(0, 0) = 0 Then
            MsgBox "Release Of DC And RC Failed.", vbInformation, "SHUTDOWN ERROR"
        End If

        If wglDeleteContext(hrc) = 0 Then
            MsgBox "Release Rendering Context Failed.", vbInformation, "SHUTDOWN ERROR"
        End If
        hrc = 0
    End If
End Sub

Public Function CreateGLWindow(Width As Integer, Height As Integer, Bits As Integer) As Boolean
    Dim PixelFormat As GLuint
    Dim pfd As PIXELFORMATDESCRIPTOR

    pfd.cColorBits = Bits
    pfd.cDepthBits = 16
    pfd.dwFlags = PFD_DRAW_TO_WINDOW Or PFD_SUPPORT_OPENGL Or PFD_DOUBLEBUFFER
    pfd.iLayerType = PFD_MAIN_PLANE
    pfd.iPixelType = PFD_TYPE_RGBA
    pfd.nSize = Len(pfd)
    pfd.nVersion = 1
    
    PixelFormat = ChoosePixelFormat(GetDC(MainFrm.hWnd), pfd)
    If PixelFormat = 0 Then
        KillGLWindow
        MsgBox "Can't Find A Suitable PixelFormat.", vbExclamation, "ERROR"
        CreateGLWindow = False
    End If

    If SetPixelFormat(GetDC(MainFrm.hWnd), PixelFormat, pfd) = 0 Then
        KillGLWindow
        MsgBox "Can't Set The PixelFormat.", vbExclamation, "ERROR"
        CreateGLWindow = False
    End If
    
    hrc = wglCreateContext(GetDC(MainFrm.hWnd))
    If (hrc = 0) Then
        KillGLWindow
        MsgBox "Can't Create A GL Rendering Context.", vbExclamation, "ERROR"
        CreateGLWindow = False
    End If

    If wglMakeCurrent(GetDC(MainFrm.hWnd), hrc) = 0 Then
        KillGLWindow
        MsgBox "Can't Activate The GL Rendering Context.", vbExclamation, "ERROR"
        CreateGLWindow = False
    End If
    
    InitGL
    
    MainFrm.Show
    SetForegroundWindow MainFrm.hWnd
    MainFrm.SetFocus
    
    CreateGLWindow = True                       ' Success
End Function
