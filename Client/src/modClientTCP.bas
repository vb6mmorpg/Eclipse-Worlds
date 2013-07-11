Attribute VB_Name = "modClientTCP"
Option Explicit
' ******************************************
' ** Communcation to server, TCP          **
' ** Winsock Control (mswinsck.ocx)       **
' ** String packets (slow and big)        **
' ******************************************
Private PlayerBuffer As clsBuffer

Sub TcpInit()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set PlayerBuffer = New clsBuffer

    ' Connect
    frmMain.Socket.RemoteHost = Options.IP
    frmMain.Socket.RemotePort = Options.Port
    
    ' Enable news now that we are done
    frmMenu.tmrUpdateNews.Enabled = True
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "TcpInit", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub DestroyTCP()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    frmMain.Socket.close
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "DestroyTCP", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub IncomingData(ByVal DataLength As Long)
    Dim buffer() As Byte
    Dim pLength As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler

    frmMain.Socket.GetData buffer, vbUnicode, DataLength
    
    PlayerBuffer.WriteBytes buffer()
    
    If PlayerBuffer.Length >= 4 Then pLength = PlayerBuffer.ReadLong(False)
    Do While pLength > 0 And pLength <= PlayerBuffer.Length - 4
        If pLength <= PlayerBuffer.Length - 4 Then
            PlayerBuffer.ReadLong
            HandleData PlayerBuffer.ReadBytes(pLength)
        End If

        pLength = 0
        If PlayerBuffer.Length >= 4 Then pLength = PlayerBuffer.ReadLong(False)
    Loop
    PlayerBuffer.Trim
    DoEvents
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "IncomingData", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Function ConnectToServer(ByVal i As Long) As Boolean
    Dim Wait As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    ' Check to see if we are already connected, if so just exit
    If IsConnected Then
        ConnectToServer = True
        Exit Function
    End If
    
    Wait = timeGetTime
    frmMain.Socket.close
    frmMain.Socket.Connect
    
    SetStatus "Connecting to server..."
    
    ' Wait until connected or 3 seconds have passed and report the server being down
    Do While (Not IsConnected) And (timeGetTime <= Wait + 1000)
        DoEvents
    Loop
    
    ConnectToServer = IsConnected
    Exit Function
    
' Error handler
ErrorHandler:
    HandleError "ConnectToServer", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Function

Function IsConnected() As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    If frmMain.Socket.State = sckConnected Then
        IsConnected = True
    End If
    Exit Function
    
' Error handler
ErrorHandler:
    HandleError "IsConnected", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Function

Function IsPlaying(ByVal Index As Long) As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    ' If the player doesn't exist, the Name will equal 0
    If Len(GetPlayerName(Index)) > 0 Then
        IsPlaying = True
    End If
    Exit Function
    
' Error handler
ErrorHandler:
    HandleError "IsPlaying", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Function

Sub SendData(ByRef data() As Byte)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    If IsConnected Then
        Set buffer = New clsBuffer
        buffer.WriteLong (UBound(data) - LBound(data)) + 1
        buffer.WriteBytes data()
        frmMain.Socket.SendData buffer.ToArray()
    End If
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendData", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

' *****************************
' ** Outgoing Client Packets **
' *****************************
Public Sub SendNewAccount(ByVal Name As String, ByVal Password As String)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CNewAccount
    buffer.WriteString GetPlayerHDSerial
    buffer.WriteLong App.Major
    buffer.WriteLong App.Minor
    buffer.WriteLong App.Revision
    buffer.WriteString Name
    buffer.WriteString Password
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendNewAccount", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendDelAccount(ByVal Name As String, ByVal Password As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CDelAccount
    buffer.WriteString GetPlayerHDSerial
    buffer.WriteLong App.Major
    buffer.WriteLong App.Minor
    buffer.WriteLong App.Revision
    buffer.WriteString Name
    buffer.WriteString Password
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendDelAccount", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendLogin(ByVal Name As String, ByVal Password As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CLogin
    buffer.WriteString GetPlayerHDSerial
    buffer.WriteLong App.Major
    buffer.WriteLong App.Minor
    buffer.WriteLong App.Revision
    buffer.WriteString Name
    buffer.WriteString Password
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendLogin", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendAddChar(ByVal Name As String, ByVal Gender As Long, ByVal ClassNum As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CAddChar
    buffer.WriteString Name
    buffer.WriteByte Gender
    buffer.WriteByte ClassNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendAddChar", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendUseChar(ByVal CharSlot As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CUseChar
    buffer.WriteLong CharSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendUseChar", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SayMsg(ByVal Text As String)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSayMsg
    buffer.WriteString Text
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SayMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub GlobalMsg(ByVal Text As String)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CGlobalMsg
    buffer.WriteString Text
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "GlobalMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub AdminMsg(ByVal Text As String)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CAdminMsg
    buffer.WriteString Text
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "AdminMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub PartyMsg(ByVal Text As String, PartyNum As Long)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CPartyMsg
    buffer.WriteString Text
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "PartyMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub EmoteMsg(ByVal Text As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CEmoteMsg
    buffer.WriteString Text
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "EmoteMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub PrivateMsg(ByVal MsgTo As String, Text As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CPrivateMsg
    buffer.WriteString MsgTo
    buffer.WriteString Text
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "PrivateMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendPlayerDir()
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CPlayerDir
    buffer.WriteLong GetPlayerDir(MyIndex)
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendPlayerDir", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendPlayerMove()
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CPlayerMove
    buffer.WriteByte Player(MyIndex).Dir
    
    If ShiftDown Then
        buffer.WriteByte MOVING_WALKING
    Else
        buffer.WriteByte MOVING_RUNNING
    End If
    
    buffer.WriteInteger Player(MyIndex).x
    buffer.WriteInteger Player(MyIndex).y
    SendData buffer.ToArray()
    Set buffer = Nothing
    
    ' Now tell the stupid client to wait.
    IsWaitingForMove = True
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendPlayerMove", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendPlayerRequestNewMap()
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestNewMap
    buffer.WriteLong GetPlayerDir(MyIndex)
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendPlayerRequestNewMap", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveMap()
    Dim packet As String
    Dim x As Long
    Dim y As Long
    Dim i As Long, Z As Long, w As Long
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler

    Set buffer = New clsBuffer
    CanMoveNow = False

    With Map
        buffer.WriteLong CMapData
        buffer.WriteString Trim$(.Name)
        buffer.WriteString Trim$(.Music)
        buffer.WriteString Trim$(.BGS)
        buffer.WriteByte .Moral
        buffer.WriteLong .Up
        buffer.WriteLong .Down
        buffer.WriteLong .Left
        buffer.WriteLong .Right
        buffer.WriteLong .BootMap
        buffer.WriteByte .BootX
        buffer.WriteByte .BootY
        
        buffer.WriteLong .Weather
        buffer.WriteLong .WeatherIntensity
        
        buffer.WriteLong .Fog
        buffer.WriteLong .FogSpeed
        buffer.WriteLong .FogOpacity
        
        buffer.WriteLong .Panorama
        
        buffer.WriteLong .Red
        buffer.WriteLong .Green
        buffer.WriteLong .Blue
        buffer.WriteLong .Alpha
        
        buffer.WriteByte .MaxX
        buffer.WriteByte .MaxY
        
        buffer.WriteByte .Npc_HighIndex
    End With

    For x = 0 To Map.MaxX
        For y = 0 To Map.MaxY
            With Map.Tile(x, y)
                For i = 1 To MapLayer.Layer_Count - 1
                    buffer.WriteLong .Layer(i).x
                    buffer.WriteLong .Layer(i).y
                    buffer.WriteLong .Layer(i).Tileset
                Next
                
                For Z = 1 To MapLayer.Layer_Count - 1
                    buffer.WriteLong .Autotile(Z)
                Next
                
                buffer.WriteByte .Type
                buffer.WriteLong .Data1
                buffer.WriteLong .Data2
                buffer.WriteLong .Data3
                buffer.WriteString .Data4
                buffer.WriteByte .DirBlock
            End With
        Next
    Next

    With Map
        For x = 1 To MAX_MAP_NPCS
            buffer.WriteLong .NPC(x)
            buffer.WriteLong .NpcSpawnType(x)
        Next
    End With
    
    ' Event Data
    buffer.WriteLong Map.EventCount
        
    If Map.EventCount > 0 Then
        For i = 1 To Map.EventCount
            With Map.events(i)
                buffer.WriteString .Name
                buffer.WriteLong .Global
                buffer.WriteLong .x
                buffer.WriteLong .y
                buffer.WriteLong .pageCount
            End With
            If Map.events(i).pageCount > 0 Then
                For x = 1 To Map.events(i).pageCount
                    With Map.events(i).Pages(x)
                        buffer.WriteLong .chkVariable
                        buffer.WriteLong .VariableIndex
                        buffer.WriteLong .VariableCondition
                        buffer.WriteLong .VariableCompare
                            
                        buffer.WriteLong .chkSwitch
                        buffer.WriteLong .SwitchIndex
                        buffer.WriteLong .SwitchCompare
                        
                        buffer.WriteLong .chkHasItem
                        buffer.WriteLong .HasItemIndex
                            
                        buffer.WriteLong .chkSelfSwitch
                        buffer.WriteLong .SelfSwitchIndex
                        buffer.WriteLong .SelfSwitchCompare
                            
                        buffer.WriteLong .GraphicType
                        buffer.WriteLong .Graphic
                        buffer.WriteLong .GraphicX
                        buffer.WriteLong .GraphicY
                        buffer.WriteLong .GraphicX2
                        buffer.WriteLong .GraphicY2
                        
                        buffer.WriteLong .MoveType
                        buffer.WriteLong .MoveSpeed
                        buffer.WriteLong .MoveFreq
                        buffer.WriteLong .MoveRouteCount
                        
                        buffer.WriteLong .IgnoreMoveRoute
                        buffer.WriteLong .RepeatMoveRoute
                            
                        If .MoveRouteCount > 0 Then
                            For y = 1 To .MoveRouteCount
                                buffer.WriteLong .MoveRoute(y).Index
                                buffer.WriteLong .MoveRoute(y).Data1
                                buffer.WriteLong .MoveRoute(y).Data2
                                buffer.WriteLong .MoveRoute(y).Data3
                                buffer.WriteLong .MoveRoute(y).Data4
                                buffer.WriteLong .MoveRoute(y).Data5
                                buffer.WriteLong .MoveRoute(y).Data6
                            Next
                        End If
                            
                        buffer.WriteLong .WalkAnim
                        buffer.WriteLong .DirFix
                        buffer.WriteLong .WalkThrough
                        buffer.WriteLong .ShowName
                        buffer.WriteLong .Trigger
                        buffer.WriteLong .CommandListCount
                        
                        buffer.WriteLong .Position
                    End With
                        
                    If Map.events(i).Pages(x).CommandListCount > 0 Then
                        For y = 1 To Map.events(i).Pages(x).CommandListCount
                            buffer.WriteLong Map.events(i).Pages(x).CommandList(y).CommandCount
                            buffer.WriteLong Map.events(i).Pages(x).CommandList(y).ParentList
                            If Map.events(i).Pages(x).CommandList(y).CommandCount > 0 Then
                                For Z = 1 To Map.events(i).Pages(x).CommandList(y).CommandCount
                                    With Map.events(i).Pages(x).CommandList(y).Commands(Z)
                                        buffer.WriteLong .Index
                                        buffer.WriteString .Text1
                                        buffer.WriteString .Text2
                                        buffer.WriteString .Text3
                                        buffer.WriteString .Text4
                                        buffer.WriteString .Text5
                                        buffer.WriteLong .Data1
                                        buffer.WriteLong .Data2
                                        buffer.WriteLong .Data3
                                        buffer.WriteLong .Data4
                                        buffer.WriteLong .Data5
                                        buffer.WriteLong .Data6
                                        buffer.WriteLong .ConditionalBranch.CommandList
                                        buffer.WriteLong .ConditionalBranch.Condition
                                        buffer.WriteLong .ConditionalBranch.Data1
                                        buffer.WriteLong .ConditionalBranch.Data2
                                        buffer.WriteLong .ConditionalBranch.Data3
                                        buffer.WriteLong .ConditionalBranch.ElseCommandList
                                        buffer.WriteLong .MoveRouteCount
                                        If .MoveRouteCount > 0 Then
                                            For w = 1 To .MoveRouteCount
                                                buffer.WriteLong .MoveRoute(w).Index
                                                buffer.WriteLong .MoveRoute(w).Data1
                                                buffer.WriteLong .MoveRoute(w).Data2
                                                buffer.WriteLong .MoveRoute(w).Data3
                                                buffer.WriteLong .MoveRoute(w).Data4
                                                buffer.WriteLong .MoveRoute(w).Data5
                                                buffer.WriteLong .MoveRoute(w).Data6
                                            Next
                                        End If
                                    End With
                                Next
                            End If
                        Next
                    End If
                Next
            End If
        Next
    End If

    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendMap", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub WarpMeTo(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CWarpMeTo
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "WarpMeTo", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub WarpToMe(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CWarpToMe
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "WarptoMe", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub WarpTo(ByVal MapNum As Integer)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CWarpTo
    buffer.WriteInteger MapNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "WarpTo", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSetAccess(ByVal Name As String, ByVal Access As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSetAccess
    buffer.WriteString Name
    buffer.WriteLong Access
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSetAccess", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSetSprite(ByVal SpriteNum As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSetSprite
    buffer.WriteLong SpriteNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSetSprite", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSetPlayerSprite(ByVal Name As String, ByVal SpriteNum As Long)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CSetPlayerSprite
    buffer.WriteLong SpriteNum
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendKick(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CKickPlayer
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendKick", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendMute(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CMutePlayer
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendMute", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendBan(ByVal Name As String, Reason As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CBanPlayer
    buffer.WriteString Name
    buffer.WriteString Reason
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendBan", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditItem()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditItem
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveItem(ByVal ItemNum As Long)
    Dim buffer As clsBuffer
    Dim ItemSize As Long
    Dim ItemData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    ItemSize = LenB(Item(ItemNum))
    ReDim ItemData(ItemSize - 1)
    CopyMemory ItemData(0), ByVal VarPtr(Item(ItemNum)), ItemSize
    buffer.WriteLong CSaveItem
    buffer.WriteLong ItemNum
    buffer.WriteBytes ItemData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditAnimation()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditAnimation
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditAnimation", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveAnimation(ByVal Animationnum As Long)
    Dim buffer As clsBuffer
    Dim AnimationSize As Long
    Dim AnimationData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    AnimationSize = LenB(Animation(Animationnum))
    ReDim AnimationData(AnimationSize - 1)
    CopyMemory AnimationData(0), ByVal VarPtr(Animation(Animationnum)), AnimationSize
    buffer.WriteLong CSaveAnimation
    buffer.WriteLong Animationnum
    buffer.WriteBytes AnimationData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveAnimation", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditNPC()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditNPC
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditNPC", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveNpc(ByVal NpcNum As Long)
    Dim buffer As clsBuffer
    Dim NpcSize As Long
    Dim NpcData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    NpcSize = LenB(NPC(NpcNum))
    ReDim NpcData(NpcSize - 1)
    CopyMemory NpcData(0), ByVal VarPtr(NPC(NpcNum)), NpcSize
    buffer.WriteLong CSaveNPC
    buffer.WriteLong NpcNum
    buffer.WriteBytes NpcData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveNpc", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditResource()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditResource
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditResource", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveResource(ByVal ResourceNum As Long)
    Dim buffer As clsBuffer
    Dim ResourceSize As Long
    Dim ResourceData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    ResourceSize = LenB(Resource(ResourceNum))
    ReDim ResourceData(ResourceSize - 1)
    CopyMemory ResourceData(0), ByVal VarPtr(Resource(ResourceNum)), ResourceSize
    buffer.WriteLong CSaveResource
    buffer.WriteLong ResourceNum
    buffer.WriteBytes ResourceData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveResource", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendMapRespawn()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CMapRespawn
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendMapRespawn", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendUseItem(ByVal InvNum As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CUseItem
    buffer.WriteByte InvNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendUseItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendDropItem(ByVal InvNum As Byte, ByVal Amount As Long)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    If InBank Or InShop > 0 Or InChat Then Exit Sub
    
    ' Do basic checks
    If InvNum < 1 Or InvNum > MAX_INV Then Exit Sub
    If PlayerInv(InvNum).Num < 1 Or PlayerInv(InvNum).Num > MAX_ITEMS Then Exit Sub
    If Item(GetPlayerInvItemNum(MyIndex, InvNum)).Type = ITEM_TYPE_CURRENCY Then
        If Amount < 1 Or Amount > PlayerInv(InvNum).Value Then Exit Sub
    End If
    
    ' Make sure it is not bound
    If GetPlayerInvItemBind(MyIndex, InvNum) = 1 Then
        Dialogue "Destroy Item", "Would you like to destroy this item?", DIALOGUE_TYPE_DESTROYITEM, True, InvNum
        Exit Sub
    End If
    
    Call SendMapDropItem(InvNum, Amount)
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendDropItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendWhosOnline()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CWhosOnline
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendWhosOnline", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendMOTDChange(ByVal MOTD As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSetMOTD
    buffer.WriteString MOTD
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendMOTDChange", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSMOTDChange(ByVal SMOTD As String)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CSetSMotd
    buffer.WriteString SMOTD
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSMOTDChange", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendGMOTDChange(ByVal GMOTD As String)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CSetGMotd
    buffer.WriteString GMOTD
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendGMOTDChange", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub
    
Public Sub SendRequestEditShop()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditShop
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditShop", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveShop(ByVal ShopNum As Long)
    Dim buffer As clsBuffer
    Dim ShopSize As Long
    Dim ShopData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    ShopSize = LenB(Shop(ShopNum))
    ReDim ShopData(ShopSize - 1)
    CopyMemory ShopData(0), ByVal VarPtr(Shop(ShopNum)), ShopSize
    buffer.WriteLong CSaveShop
    buffer.WriteLong ShopNum
    buffer.WriteBytes ShopData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveShop", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditSpell()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditSpell
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditSpell", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveSpell(ByVal SpellNum As Long)
    Dim buffer As clsBuffer
    Dim SpellSize As Long
    Dim SpellData() As Byte
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    SpellSize = LenB(Spell(SpellNum))
    ReDim SpellData(SpellSize - 1)
    CopyMemory SpellData(0), ByVal VarPtr(Spell(SpellNum)), SpellSize
    buffer.WriteLong CSaveSpell
    buffer.WriteLong SpellNum
    buffer.WriteBytes SpellData
    SendData buffer.ToArray()
    
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveSpell", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditMap()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditMap
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditMap", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendChangeInvSlots(ByVal OldSlot As Byte, ByVal NewSlot As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSwapInvSlots
    buffer.WriteByte OldSlot
    buffer.WriteByte NewSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSwapHotbarSlots", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendChangeSpellSlots(ByVal OldSlot As Byte, ByVal NewSlot As Byte)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler

    If SpellBuffer > 0 Then
        If PlayerSpells(OldSlot) = SpellBuffer Or PlayerSpells(NewSlot) = SpellBuffer Then
            AddText "You cannot swap spells those spells while casting!", BrightRed
            Exit Sub
        End If
    End If

    Set buffer = New clsBuffer
    buffer.WriteLong CSwapSpellSlots
    buffer.WriteByte OldSlot
    buffer.WriteByte NewSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendChangeSpellSlots", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendSwapHotbarSlots(ByVal OldSlot As Byte, ByVal NewSlot As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSwapHotbarSlots
    buffer.WriteByte OldSlot
    buffer.WriteByte NewSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendChangeInvSlots", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub CheckPing()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    PingStart = timeGetTime
    Set buffer = New clsBuffer
    buffer.WriteLong CCheckPing
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "CheckPing", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendUnequip(ByVal EqNum As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CUnequip
    buffer.WriteLong EqNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendUnequip", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestItems()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestItems
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestItems", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestAnimations()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestAnimations
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestAnimations", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestNpcs()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestNPCs
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestNpcs", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestResources()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestResources
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestResources", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestSpells()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestSpells
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestSpells", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestShops()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestShops
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendRequestShops", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendSpawnItem(ByVal TmpItem As Long, ByVal TmpAmount As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSpawnItem
    buffer.WriteLong TmpItem
    buffer.WriteLong TmpAmount
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSpawnItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendTrainStat(ByVal StatNum As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CUseStatPoint
    buffer.WriteByte StatNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendTrainStat", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestLevelUp()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestLevelUp
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestLevelUp", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub BuyItem(ByVal ShopSlot As Long)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CBuyItem
    buffer.WriteLong ShopSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "BuyItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SellItem(ByVal InvSlot As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSellItem
    buffer.WriteByte InvSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SellItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub DepositItem(ByVal InvSlot As Byte, ByVal Amount As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CDepositItem
    buffer.WriteByte InvSlot
    buffer.WriteLong Amount
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "DepositItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub WithdrawItem(ByVal BankSlot As Byte, ByVal Amount As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CWithdrawItem
    buffer.WriteByte BankSlot
    buffer.WriteLong Amount
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "WithdrawItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub CloseBank()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CCloseBank
    SendData buffer.ToArray()
    Set buffer = Nothing
    InBank = False
    frmMain.picBank.Visible = False
    Exit Sub
        
' Error handler
ErrorHandler:
    HandleError "CloseBank", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub CloseTrade()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    frmMain.picCurrency.Visible = False
    TmpCurrencyItem = 0
    CurrencyMenu = 0 ' Clear
    DeclineTrade
    Exit Sub
        
' Error handler
ErrorHandler:
    HandleError "CloseTrade", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub CloseShop()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    
    buffer.WriteLong CCloseShop
    SendData buffer.ToArray()
    Set buffer = Nothing
    
    frmMain.picShop.Visible = False
    InShop = 0
    TryingToFixItem = False
    Exit Sub
        
' Error handler
ErrorHandler:
    HandleError "CloseShop", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SwapBankSlots(ByVal OldSlot As Byte, ByVal NewSlot As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSwapBankSlots
    buffer.WriteByte OldSlot
    buffer.WriteByte NewSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SwapBankSlots", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub AdminWarp(ByVal x As Long, ByVal y As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CAdminWarp
    buffer.WriteLong x
    buffer.WriteLong y
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "AdminWarp", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub FixItem(ByVal InvSlot As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CFixItem
    buffer.WriteByte InvSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "FixItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub AcceptTrade()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CAcceptTrade
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "AcceptTrade", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub DeclineTrade()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler

    Set buffer = New clsBuffer
    buffer.WriteLong CDeclineTrade
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "DeclineTrade", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub TradeItem(ByVal InvSlot As Byte, ByVal Amount As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CTradeItem
    buffer.WriteByte InvSlot
    buffer.WriteLong Amount
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "TradeItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub UntradeItem(ByVal InvSlot As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CUntradeItem
    buffer.WriteByte InvSlot
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "UntradeItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendHotbarChange(ByVal SType As Byte, ByVal Slot As Byte, ByVal HotbarNum As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    If SType = 1 Then
        ' Don't add None/Currency/Auto Life type items
        If Item(GetPlayerInvItemNum(MyIndex, Slot)).Type = ITEM_TYPE_CURRENCY Or Item(GetPlayerInvItemNum(MyIndex, Slot)).Type = ITEM_TYPE_NONE Or Item(GetPlayerInvItemNum(MyIndex, Slot)).Type = ITEM_TYPE_AUTOLIFE Then
            Call AddText("You can't add that type of item to your hotbar!", BrightRed)
            Exit Sub
        End If
    End If
    
    Set buffer = New clsBuffer
    buffer.WriteLong CHotbarChange
    buffer.WriteByte SType
    buffer.WriteByte Slot
    buffer.WriteByte HotbarNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendHotbarChange", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendHotbarUse(ByVal Slot As Long)
    Dim x As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    ' Check the hotbar type
    If Hotbar(Slot).SType = 1 Then ' Item
        For x = 1 To MAX_INV
            ' Is the item matching the hotbar
            If GetPlayerInvItemNum(MyIndex, x) = Hotbar(Slot).Slot Then
                SendUseItem x
                Exit Sub
            End If
        Next
        
        For x = 1 To Equipment.Equipment_Count - 1
            If Player(MyIndex).Equipment(x).Num = Hotbar(Slot).Slot Then
                SendUnequip x
                Exit Sub
            End If
        Next
    ElseIf Hotbar(Slot).SType = 2 Then ' Spell
        For x = 1 To MAX_PLAYER_SPELLS
            ' Is the spell matching the hotbar
            If PlayerSpells(x) = Hotbar(Slot).Slot Then
                ' Found it, cast it
                CastSpell x
                Exit Sub
            End If
        Next
    End If
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendHotbarUse", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub GuildMsg(ByVal Text As String)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    
    buffer.WriteLong CGuildMsg
    buffer.WriteString Text
    
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "GuildMsg", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendGuildAccept()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    
    buffer.WriteLong CAcceptGuild
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendGuildAccept", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub PlayerSearch(ByVal CurX As Long, ByVal CurY As Long)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    If IsInBounds Then
        Set buffer = New clsBuffer
        buffer.WriteLong CSearch
        buffer.WriteLong CurX
        buffer.WriteLong CurY
        SendData buffer.ToArray()
        Set buffer = Nothing
    End If
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "PlayerSearch", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendTradeRequest()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CTradeRequest
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendTradeRequest", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendAcceptTradeRequest()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CAcceptTradeRequest
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendAcceptTradeRequest", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendDeclineTradeRequest()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CDeclineTradeRequest
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendDeclineTradeRequest", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendPartyLeave()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CPartyLeave
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendPartyLeave", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendPartyRequest(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CPartyRequest
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendPartyRequest", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendAcceptParty()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CAcceptParty
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendAcceptParty", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendDeclineParty()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CDeclineParty
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendDeclineParty", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendGuildDecline()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    
    buffer.WriteLong CDeclineGuild
    buffer.WriteLong DialogueData1
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendGuildCreate(ByVal Name As String)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    
    buffer.WriteLong CGuildCreate
    buffer.WriteString Name
    
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendGuildChangeAccess(ByVal Name As String, ByVal Access As Byte)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    
    buffer.WriteLong CGuildChangeAccess
    buffer.WriteString Name
    buffer.WriteByte Access
    
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendMapReport()
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CMapReport
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendMapReport", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendOpenMaps()
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong COpenMaps
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub

' Error handler
ErrorHandler:
    HandleError "SendOpenMaps", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendCanTrade()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CCanTrade
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendAddFriend(ByVal FriendsName As String)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CAddFriend
    buffer.WriteString FriendsName
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendRemoveFriend(ByVal FriendsName As String)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRemoveFriend
    buffer.WriteString FriendsName
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub UpdateFriendsList()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CFriendsList
    SendData buffer.ToArray
    Set buffer = Nothing
End Sub

Public Sub SendAddFoe(ByVal FoesName As String)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CAddFoe
    buffer.WriteString FoesName
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub SendRemoveFoe(ByVal FoesName As String)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRemoveFoe
    buffer.WriteString FoesName
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Public Sub UpdateFoesList()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CFoesList
    SendData buffer.ToArray
    Set buffer = Nothing
End Sub

Public Sub UpdateSpells()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CSpells
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendRequestPlayerData()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestPlayerData
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendRequestPlayerStats()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestPlayerStats
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendRequestSpellCooldown(ByVal Slot As Byte)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestSpellCooldown
    buffer.WriteByte Slot
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendRequestBans()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestBans
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendRequestTitles()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestTitles
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub UpdateData()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CUpdateData
    buffer.WriteString GetPlayerHDSerial
    buffer.WriteLong App.Major
    buffer.WriteLong App.Minor
    buffer.WriteLong App.Revision
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendLeaveGame()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CLeaveGame
    SendData buffer.ToArray()
    Set buffer = Nothing
    frmMain.Socket.close
End Sub

Sub SendSaveBan(ByVal BanNum As Long)
    Dim buffer As clsBuffer
    Dim BanSize As Long
    Dim BanData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    BanSize = LenB(Ban(BanNum))
    ReDim BanData(BanSize - 1)
    CopyMemory BanData(0), ByVal VarPtr(Ban(BanNum)), BanSize
    buffer.WriteLong CSaveBan
    buffer.WriteLong BanNum
    buffer.WriteBytes BanData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveBan", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestEditBan()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    ' Get the new ban data
    SendRequestBans
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditBans
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditBan", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendMapDropItem(InvNum As Byte, Amount As Long)
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    
    buffer.WriteLong CMapDropItem
    buffer.WriteByte InvNum
    buffer.WriteLong Amount
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendSaveTitle(ByVal TitleNum As Long)
    Dim buffer As clsBuffer
    Dim TitleSize As Long
    Dim TitleData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    TitleSize = LenB(Title(TitleNum))
    ReDim TitleData(TitleSize - 1)
    CopyMemory TitleData(0), ByVal VarPtr(Title(TitleNum)), TitleSize
    buffer.WriteLong CSaveTitle
    buffer.WriteLong TitleNum
    buffer.WriteBytes TitleData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveTitle", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestEditTitle()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditTitles
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditTitle", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendSetTitle(TitleNum As Byte)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSetTitle
    buffer.WriteByte TitleNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSetTitle", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendGuildInvite(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CGuildInvite
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendGuildInvite", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendGuildRemove(ByVal Name As String)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CGuildRemove
    buffer.WriteString Name
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendGuildRemove", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendGuildDisband()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CGuildDisband
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendGuildDisband", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendChangeStatus(Index As Long, Status As String)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    If Trim$(Player(MyIndex).Status) = "Muted" Then
        Call AddText("You can't change your status when your muted!", BrightRed)
        Exit Sub
    End If
   
    Set buffer = New clsBuffer
    
    buffer.WriteLong CChangeStatus
    buffer.WriteString Status
    
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendChangeStatus", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendSaveMoral(ByVal MoralNum As Long)
    Dim buffer As clsBuffer
    Dim MoralSize As Long
    Dim MoralData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    MoralSize = LenB(Moral(MoralNum))
    ReDim MoralData(MoralSize - 1)
    CopyMemory MoralData(0), ByVal VarPtr(Moral(MoralNum)), MoralSize
    buffer.WriteLong CSaveMoral
    buffer.WriteLong MoralNum
    buffer.WriteBytes MoralData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveMoral", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestEditMoral()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditMorals
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditMoral", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestMorals()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestMorals
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendSaveClass(ByVal ClassNum As Long)
    Dim buffer As clsBuffer
    Dim ClassSize As Long
    Dim ClassData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    ClassSize = LenB(Class(ClassNum))
    ReDim ClassData(ClassSize - 1)
    CopyMemory ClassData(0), ByVal VarPtr(Class(ClassNum)), ClassSize
    buffer.WriteLong CSaveClass
    buffer.WriteLong ClassNum
    buffer.WriteBytes ClassData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveClass", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestEditClass()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditClasses
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditClass", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestClasses()
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestClasses
    SendData buffer.ToArray()
    Set buffer = Nothing
End Sub

Sub SendDestroyItem(ByVal InvNum As Integer)
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    
    buffer.WriteLong CDestoryItem
    buffer.WriteInteger InvNum
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendDestroyItem", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendRequestEditEmoticon()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditEmoticons
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEditEmoticon", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendSaveEmoticon(ByVal EmoticonNum As Long)
    Dim buffer As clsBuffer
    Dim EmoticonSize As Long
    Dim EmoticonData() As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    EmoticonSize = LenB(Emoticon(EmoticonNum))
    ReDim EmoticonData(EmoticonSize - 1)
    CopyMemory EmoticonData(0), ByVal VarPtr(Emoticon(EmoticonNum)), EmoticonSize
    buffer.WriteLong CSaveEmoticon
    buffer.WriteLong EmoticonNum
    buffer.WriteBytes EmoticonData
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSaveEmoticon", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendRequestEmoticons()
    Dim buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEmoticons
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendRequestEmoticons", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Public Sub SendEmoticonEditor()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Dim buffer As clsBuffer
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestEditEmoticons
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendEmoticonEditor", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendCheckEmoticon(ByVal EmoticonNum As Long)
    Dim buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler

    Set buffer = New clsBuffer
    
    buffer.WriteLong CCheckEmoticon
    buffer.WriteLong EmoticonNum
    
    SendData buffer.ToArray()
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendCheckEmoticon", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub RequestSwitchesAndVariables()
    Dim i As Long, buffer As clsBuffer
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CRequestSwitchesAndVariables
    
    SendData buffer.ToArray
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "RequestSwitchesAndVariables", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendSwitchesAndVariables()
    Dim i As Long, buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CSwitchesAndVariables
    
    For i = 1 To MAX_SWITCHES
        buffer.WriteString Switches(i)
    Next
    
    For i = 1 To MAX_VARIABLES
        buffer.WriteString Variables(i)
    Next
    
    SendData buffer.ToArray
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendSwitchesAndVariables", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub

Sub SendFinishTutorial()
    Dim buffer As clsBuffer
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo ErrorHandler
    
    Set buffer = New clsBuffer
    buffer.WriteLong CFinishTutorial
    SendData buffer.ToArray()
    Set buffer = Nothing
    Exit Sub
    
' Error handler
ErrorHandler:
    HandleError "SendFinishTutorial", "modClientTCP", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
End Sub
