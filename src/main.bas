Attribute VB_Name = "MainMd"
Option Explicit

Private Type DCoord
    X As Integer
    Y As Integer
End Type

Private Type WDispList
    DL As GLuint
    Char As String * 1
    SP As DCoord
    EP As DCoord
End Type

Private Type TPin
    X As Integer
    Y As Integer
    Color As Integer
    Txt As String
    Show As Boolean
End Type

Private Type TGroup
    Start As Integer
    Stop As Integer
    Color As Integer
    Txt As String
End Type

Private Type TWave
    DL As GLuint
    Used As Boolean
End Type

Public Loaded As Boolean

Public FontTex As GLuint
Public PinTex As GLuint

Public PinList(255) As TPin
Public GroupStack(256) As TGroup

Public UsedWave As Boolean

Public nPins As Integer
Public nGroups As Integer
Public GIdx As Integer


' Settings
Public LiveRefresh As Boolean
Public Spacing As Single

Public nWaves As Integer

Public Nav_X As Integer
Public Nav_Y As Integer

' Display Lists
Public PinDL As GLuint
Public TicksDL As GLuint
Public Waves(256) As TWave    ' Blocks
Public CharDL(128) As GLuint    ' Characters

Public DispLists(256) As WDispList  ' For blocks

Public FilePath As String

Public XMargin As Integer
Public YMargin As Integer

Public Saved As Boolean
Public DataTxt() As String


Public Keys(255) As Boolean             ' used to keep track of key_downs

Private hrc As Long

Public Sub Display()
    Dim w As Integer
    Dim PinTextLen As Integer
    
    If Loaded = False Then Exit Sub
    
    glMatrixMode mmModelView        ' Select The Modelview Matrix
    glLoadIdentity                  ' Reset The Modelview Matrix
    
    glClearColor 1, 1, 1, 1
    glClear clrColorBufferBit Or clrDepthBufferBit
    
    glBlendFunc sfSrcAlpha, dfOneMinusSrcAlpha
    glHint GL_LINE_SMOOTH_HINT, GL_NICEST
    
    glTranslatef Nav_X, Nav_Y, 0#
    glPushMatrix
    
    glScalef Spacing, 1, 1
    
    ' Draw ticks
    glColor4b 0, 0, 0, 31
    glCallList TicksDL
    
    glPopMatrix
    glTranslatef 0, YMargin, 0
    glPushMatrix
    
    ' Draw groups
    For w = 0 To nGroups
        SetDataColor GroupStack(w).Color, 15
        glBegin bmPolygon
            glVertex2f 0, GroupStack(w).Start
            glVertex2f MainFrm.ScaleWidth, GroupStack(w).Start
            glVertex2f MainFrm.ScaleWidth, GroupStack(w).Stop
            glVertex2f 0, GroupStack(w).Stop
        glEnd
    Next w
    
    ' Draw waves
    For w = 0 To nWaves - 1
        If Waves(w).Used = True Then glCallList Waves(w).DL
    Next w
    
    ' Draw pins
    glBlendFunc sfSrcAlpha, dfOneMinusSrcAlpha
    glEnable glcTexture2D
    glBindTexture glTexture2D, PinTex
    For w = 0 To nPins - 1
        glPopMatrix
        glPushMatrix
        glTranslatef (PinList(w).X * Spacing) - 10, PinList(w).Y, 0
        SetDataColor PinList(w).Color, 127
        glCallList PinDL
    Next w
    glDisable glcTexture2D
    
    ' Draw pin bubble if needed
    For w = 0 To nPins - 1
        If PinList(w).Show = True Then
            glPopMatrix
            glPushMatrix
            PinTextLen = Len(PinList(w).Txt) * 8 + 16
            glTranslatef PinList(w).X + 8, PinList(w).Y + 10, 0
            glColor4b 120, 120, 120, 90
            glBegin bmPolygon
                glVertex2f 0, 0
                glVertex2f 8, -8
                glVertex2f PinTextLen, -8
                glVertex2f PinTextLen, 8
                glVertex2f 8, 8
                glVertex2f 0, 0
            glEnd
            SetDataColor PinList(w).Color, 70
            glBegin bmLineStrip
                glVertex2f 0, 0
                glVertex2f 8, -8
                glVertex2f PinTextLen, -8
                glVertex2f PinTextLen, 8
                glVertex2f 8, 8
                glVertex2f 0, 0
            glEnd
            SetDataColor PinList(w).Color, 127
            RenderText PinList(w).Txt, 12, -8
        End If
    Next w
    
    glPopMatrix

    SwapBuffers MainFrm.hDC
End Sub

Sub ProcessFields(Fields() As String, TypeMatch As String, w As Integer)
    Dim XDraw As Integer
    Dim YDraw As Integer
    Dim c As Integer
    Dim st As Integer
    Dim blk As String * 1
    Dim ch As String * 1
    Dim AscP As Integer
    Dim LastBlk As String * 1
    Dim PBlk As String * 1
    Dim Steps As Integer
    Dim WaveDef As String
    Dim DataColor As Integer
    Dim DataState As Integer
    Dim DStart As Integer
    Dim eq, f, d As Integer
    Dim FieldType As String
    Dim FieldData As String
    Dim Found As Boolean
    Dim l As Integer
    Dim dti As Integer
    Dim DF() As String
    Dim LastD As Integer
    Dim DAlpha As Integer
    Dim sx, sy, ex, ey As Integer
    
    Found = False
    For f = 0 To UBound(Fields)
        eq = InStr(1, Fields(f), ":")   ' Field has type:data pair ?
        If eq > 0 Then
            Fields(f) = Replace(Fields(f), Chr(9), " ")    ' Tab to space
            FieldType = Trim(LCase(Left(Fields(f), eq - 1)))
            FieldData = Trim(Right(Fields(f), Len(Fields(f)) - eq))
        Else
            ' Line only has field with no data
            FieldType = Trim(LCase(Fields(f)))
        End If
        If FieldType = TypeMatch Then
            Found = True
            Exit For
        End If
    Next f
        
    If Found = False Then Exit Sub
    
    If FieldType = "ruler" Then
        RenderRuler FieldData
    ElseIf FieldType = "name" Then
        RenderName FieldData
        UsedWave = True
    ElseIf FieldType = "data" Then
        RenderData FieldData
    ElseIf FieldType = "pin" Then
        RenderPin FieldData, w * 20
    ElseIf FieldType = "group" Then
        GroupStack(GIdx).Start = (w * 20) - 4
        DF = Split(FieldData, ",")
        GroupStack(GIdx).Txt = DF(0)
        GroupStack(GIdx).Color = Val(DF(1))
        If GIdx > nGroups Then nGroups = GIdx
        GIdx = GIdx + 1
    ElseIf FieldType = "groupend" Then
        If GIdx > 0 Then
            GIdx = GIdx - 1
            GroupStack(GIdx).Stop = (w * 20) - 4
        End If
    ElseIf FieldType = "wave" Then
        UsedWave = True
        LastBlk = "z"   ' Default block
        DataState = -1
        dti = 0
        
        glPushMatrix
        glTranslatef XMargin, 0, 0
        
        For c = 0 To Len(FieldData) - 1
            ' Draw
            XDraw = XMargin + (c * 15)
            
            PBlk = Mid(FieldData, c + 1, 1)
            blk = PBlk
            
            If PBlk = "." Then
                If LastBlk = "H" Then
                    PBlk = "h"          ' Adapt
                ElseIf LastBlk = "L" Then
                    PBlk = "l"          ' Adapt
                Else
                    PBlk = LastBlk      ' Repeat
                End If
                blk = PBlk
            End If
            
            AscP = Asc(PBlk)
            If (AscP >= &H30 And AscP <= &H36) Or PBlk = "=" Then   ' Start data
                If DataState = -1 Then
                    If PBlk = "=" Then
                        DataColor = 0
                    Else
                        DataColor = Asc(PBlk) - &H30
                    End If
                    If Not NextIsDot(FieldData, c) Then
                        blk = "u"
                        DStart = XDraw
                        DataState = -2
                    Else
                        DataState = 0
                    End If
                    DAlpha = 31
                End If
            Else
                DataColor = 0
                DAlpha = 127
            End If
            
            If DataState = 0 Then
                DStart = XDraw
                blk = "s"
            End If
            If DataState = 1 Then blk = "d"
            If DataState > -1 And Not NextIsDot(FieldData, c) Then
                blk = "e"
                DataState = -2
            End If
            
            ' Look for block def
            If PBlk <> "." Then
                d = 0
                Do While True
                    ch = DispLists(d).Char
                    If ch = " " Then
                        d = 0
                        Exit Do
                    End If
                    If ch = blk Then Exit Do
                    d = d + 1
                Loop
            End If
            
            glColor4b 0, 0, 0, 127
            
            ' Transition
            If c > 0 Then
                sx = DispLists(LastD).EP.X - 15
                sy = DispLists(LastD).EP.Y
                ex = DispLists(d).SP.X
                ey = DispLists(d).SP.Y
                If (sx <> ex) Or (sy <> ey) Then
                    glBegin bmLines
                        glVertex2d sx, sy
                        glVertex2d ex, ey
                    glEnd
                End If
            End If
            
            SetDataColor DataColor, DAlpha
            glCallList DispLists(d).DL
            
            If DataState = 0 Then DataState = 1
            If DataState = -2 Then
                If (DataTxt(0) <> "") Then
                    If dti <= UBound(DataTxt) Then
                        SetDataColor DataColor, 127
                        RenderText DataTxt(dti), -(((XDraw - DStart) / 2) + (Len(DataTxt(dti)) * 4)) + 7, 0
                        dti = dti + 1
                    End If
                End If
                DataState = -1
            End If
            
            LastBlk = PBlk
            LastD = d
            
            glTranslatef 15, 0, 0
        Next c
        
        glPopMatrix
    End If
End Sub
