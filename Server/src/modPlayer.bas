Attribute VB_Name = "modPlayer"
Option Explicit

Sub HandleUseChar(ByVal Index As Long)
    If Not IsPlaying(Index) Then
        Call JoinGame(Index)
        Call AddLog(GetPlayerLogin(Index) & "/" & GetPlayerName(Index) & " has began playing " & Options.Name & ".", "Player")
        Call TextAdd(GetPlayerLogin(Index) & "/" & GetPlayerName(Index) & " has began playing " & Options.Name & ".")
        Call UpdateCaption
    End If
End Sub

Sub JoinGame(ByVal Index As Long)
    Dim i As Long
    Dim n As Long
    Dim Color As Long

    ' Set the flag so we know the person is in the game
    tempplayer(Index).InGame = True

    ' Update the log
    frmServer.lvwInfo.ListItems(Index).SubItems(1) = GetPlayerIP(Index)
    frmServer.lvwInfo.ListItems(Index).SubItems(2) = GetPlayerLogin(Index)
    frmServer.lvwInfo.ListItems(Index).SubItems(3) = GetPlayerName(Index)
    
    ' Send an ok to client to start receiving in game data
    Call SendLogin(Index)

    TotalPlayersOnline = TotalPlayersOnline + 1
    
    ' Send data
    Call SendItems(Index)
    Call SendAnimations(Index)
    Call SendNPCs(Index)
    Call SendShops(Index)
    Call SendSpells(Index)
    Call SendResources(Index)
    Call SendInventory(Index)
    Call SendWornEquipment(Index)
    Call SendMapEquipment(Index)
    Call CheckEquippedItems(Index)
    Call SendHotbar(Index)
    Call SendTitles(Index)
    Call SendMorals(Index)
    Call SendEmoticons(Index)
    Call SendQuests(Index)
    
    ' Spell Cooldowns
    For i = 1 To MAX_PLAYER_SPELLS
        If GetPlayerSpell(Index, i) > 0 Then
            ' Check if the CD has expired
            If GetPlayerSpellCD(Index, i) - timeGetTime < 1 Then Call SetPlayerSpellCD(Index, i, 0)
            If GetPlayerSpellCD(Index, i) - timeGetTime >= Spell(GetPlayerSpell(Index, i)).CDTime * 1000 Then Call SetPlayerSpellCD(Index, i, 0)
            If GetPlayerSpellCD(Index, i) <= timeGetTime Then Call SetPlayerSpellCD(Index, i, 0)
            
            ' Send it
            Call SendSpellCooldown(Index, i)
        End If
    Next
    
    ' Check for glitches in the inventory
    Call UpdatePlayerItems(Index)
    
    ' Check for glitches in equipment
    Call UpdatePlayerEquipmentItems(Index)
    
    ' Send the player's data
    Call SetPlayerQuestData(Index)
    'Call SendPlayerData(Index) ' Above line does this as well
    
    
    ' Send vitals to player of all other players online
    For n = 1 To Player_HighIndex
        For i = 1 To Vitals.Vital_Count - 1
            If IsPlaying(n) Then
                Call SendVitalTo(Index, n, i) ' Sends all players to new player
                
                If Not Index = n Then
                    Call SendVitalTo(n, Index, i) ' Sends new player to logged in players
                End If
            End If
        Next
    Next
    
    ' Send other data
    Call SendPlayerStatus(Index)
    Call SendPlayerExp(Index)
    
    ' Warp the player to their saved location
    Call PlayerWarp(Index, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index), True)
    
    ' Send welcome messages
    Call SendWelcome(Index)

    ' Send Resource cache
    For i = 0 To ResourceCache(GetPlayerMap(Index)).Resource_Count
        SendResourceCacheTo Index, i
    Next
    
    Call UpdateClassData(Index)
    
    ' Send a global message that they joined
    If GetPlayerAccess(Index) <= STAFF_MODERATOR Then
        If Class(GetPlayerClass(Index)).Color = Orange Then
            Color = RGB(255, 165, 0)
        Else
            Color = Class(GetPlayerClass(Index)).Color
        End If
        
        Call GlobalMsg(GetPlayerName(Index) & " has joined " & Options.Name & "!", Color)
    Else
         ' Color for access
        Select Case GetPlayerAccess(Index)
            Case 0
                Color = 15
            Case 1
                Color = 3
            Case 2
                Color = 2
            Case 3
                Color = BrightBlue
            Case 4
                Color = Yellow
            Case 5
                Color = RGB(255, 165, 0)
        End Select
            
        Call GlobalMsg(GetPlayerName(Index) & " has joined " & Options.Name & "!", Color)
    End If

    ' Send the flag so they know they can start doing stuff
    Call SendInGame(Index)
    
    ' Refresh the friends list to all players online
    For i = 1 To Player_HighIndex
        Call UpdateFriendsList(i)
    Next
    
    ' Refresh the foes list to all players online
    For i = 1 To Player_HighIndex
        Call UpdateFoesList(i)
    Next
    
    ' Update guild list
    If GetPlayerGuild(Index) > 0 Then
        Call SendPlayerGuildMembers(Index)
    End If
End Sub

Sub LeftGame(ByVal Index As Long)
    Dim n As Long, i As Long
    Dim TradeTarget As Long

    If Index < 1 Or Index > MAX_PLAYERS Then Exit Sub
    
    If tempplayer(Index).InGame Then
        tempplayer(Index).InGame = False
        ' Check if player was the only player on the map and stop npc processing if so
        If GetTotalMapPlayers(GetPlayerMap(Index)) < 1 Then
            PlayersOnMap(GetPlayerMap(Index)) = NO
        End If
        
        ' Clear any invites out
        If tempplayer(Index).TradeRequest > 0 Or tempplayer(Index).PartyInvite > 0 Or tempplayer(Index).GuildInvite > 0 Then
            If tempplayer(Index).TradeRequest > 0 Then
                Call DeclineTradeRequest(Index)
            End If
            
            If tempplayer(Index).PartyInvite > 0 Then
                Call Party_InviteDecline(tempplayer(Index).PartyInvite, Index)
            End If
            
            If tempplayer(Index).GuildInvite > 0 Then
                Call DeclineGuildInvite(Index)
            End If
        End If
        
        ' Cancel any trade they're in
        If tempplayer(Index).InTrade > 0 Then
            TradeTarget = tempplayer(Index).InTrade
            PlayerMsg TradeTarget, Trim$(GetPlayerName(Index)) & " has declined the trade!", BrightRed
            
            ' Clear out trade
            For i = 1 To MAX_INV
                tempplayer(TradeTarget).TradeOffer(i).Num = 0
                tempplayer(TradeTarget).TradeOffer(i).Value = 0
            Next
            
            tempplayer(TradeTarget).InTrade = 0
            SendCloseTrade TradeTarget
        End If
        
        ' Leave party
        Party_PlayerLeave Index

        ' Loop through entire map and purge npc targets from player
        For i = 1 To Map(GetPlayerMap(Index)).NPC_HighIndex
            If MapNPC(GetPlayerMap(Index)).NPC(i).Num > 0 Then
                If MapNPC(GetPlayerMap(Index)).NPC(i).targetType = TARGET_TYPE_PLAYER Then
                    If MapNPC(GetPlayerMap(Index)).NPC(i).target = Index Then
                        MapNPC(GetPlayerMap(Index)).NPC(i).target = 0
                        MapNPC(GetPlayerMap(Index)).NPC(i).targetType = TARGET_TYPE_NONE
                        Call SendMapNPCTarget(GetPlayerMap(Index), i, 0, 0)
                    End If
                End If
            End If
        Next
        
        ' Refresh guild members
        For i = 1 To Player_HighIndex
            If IsPlaying(i) Then
                If Not i = Index Then
                    If GetPlayerGuild(i) = GetPlayerGuild(Index) Then
                        SendPlayerGuildMembers i, Index
                    End If
                End If
            End If
        Next
        
        ' Send a global message that they left
        If GetPlayerAccess(Index) <= STAFF_MODERATOR Then
            Call GlobalMsg(GetPlayerName(Index) & " has left " & Options.Name & "!", Grey)
        Else
            Call GlobalMsg(GetPlayerName(Index) & " has left " & Options.Name & "!", DarkGrey)
        End If
        
        Call TextAdd(GetPlayerName(Index) & " has disconnected from " & Options.Name & ".")
        Call SendLeftGame(Index)
        TotalPlayersOnline = TotalPlayersOnline - 1
        
        ' Save and clear data
        Call SaveAccount(Index)
        Call ClearAccount(Index)
        
        ' Refresh the friends list of all players online
        For i = 1 To Player_HighIndex
            Call UpdateFriendsList(i)
        Next
        
        ' Refresh the foes list of all players online
        For i = 1 To Player_HighIndex
            Call UpdateFoesList(i)
        Next
    End If
End Sub

Sub PlayerWarp(ByVal Index As Long, ByVal MapNum As Integer, ByVal X As Long, ByVal Y As Long, Optional ByVal NeedMap As Boolean = False, Optional ByVal Dir As Integer = -1)
    Dim ShopNum As Long
    Dim OldMap As Long
    Dim i As Long
    Dim buffer As clsBuffer

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or MapNum <= 0 Or MapNum > MAX_MAPS Then Exit Sub

    ' Check if you are out of bounds
    If X > Map(MapNum).MaxX Then X = Map(MapNum).MaxX
    If Y > Map(MapNum).MaxY Then Y = Map(MapNum).MaxY
    If X < 0 Then X = 0
    If Y < 0 Then Y = 0
    
    ' Save old map to send erase player data to
    OldMap = GetPlayerMap(Index)
    
    If OldMap <> MapNum Then
        UpdateMapBlock OldMap, GetPlayerX(Index), GetPlayerY(Index), False
    End If
    
    Call SetPlayerX(Index, X)
    Call SetPlayerY(Index, Y)
    UpdateMapBlock MapNum, X, Y, True
    
    ' Set direction
    If Dir > -1 Then
        Call SetPlayerDir(Index, Dir)
    End If
    
    ' if same map then just send their co-ordinates
    If MapNum = GetPlayerMap(Index) And Not NeedMap Then
        Call SendPlayerXY(Index)
        
        ' Clear spell casting
        ClearAccountSpellBuffer Index
        Exit Sub
    End If
    
    ' Clear events
    tempplayer(Index).EventProcessingCount = 0
    tempplayer(Index).EventMap.CurrentEvents = 0
    
    ' Clear target
    tempplayer(Index).target = 0
    tempplayer(Index).targetType = TARGET_TYPE_NONE
    SendPlayerTarget Index

    ' Loop through entire map and purge npc targets from player
    For i = 1 To Map(GetPlayerMap(Index)).NPC_HighIndex
        If MapNPC(GetPlayerMap(Index)).NPC(i).Num > 0 Then
            If MapNPC(GetPlayerMap(Index)).NPC(i).targetType = TARGET_TYPE_PLAYER Then
                If MapNPC(GetPlayerMap(Index)).NPC(i).target = Index Then
                    MapNPC(GetPlayerMap(Index)).NPC(i).target = 0
                    MapNPC(GetPlayerMap(Index)).NPC(i).targetType = TARGET_TYPE_NONE
                    Call SendMapNPCTarget(OldMap, i, 0, 0)
                End If
            End If
        End If
    Next
    
    ' Leave the old map
    If Not OldMap = MapNum Then
        Call SendLeaveMap(Index, OldMap)
        
        ' Set the new map
        Call SetPlayerMap(Index, MapNum)
    End If
    
    ' Send player's equipment to new map
    SendMapEquipment Index
    
    ' Send equipment of all people on new map
    If GetTotalMapPlayers(MapNum) > 0 Then
        For i = 1 To Player_HighIndex
            If IsPlaying(i) Then
                If GetPlayerMap(i) = MapNum Then
                    SendMapEquipmentTo i, Index
                End If
            End If
        Next
    End If
    
    ' Now we check if there were any players left on the map the player just left, and if not stop processing npcs
    If GetTotalMapPlayers(OldMap) = 0 Then
        PlayersOnMap(OldMap) = NO
        
        ' Get all NPCs' vitals
        For i = 1 To Map(OldMap).NPC_HighIndex
            If MapNPC(OldMap).NPC(i).Num > 0 Then
                MapNPC(OldMap).NPC(i).Vital(Vitals.HP) = GetNPCMaxVital(MapNPC(OldMap).NPC(i).Num, Vitals.HP)
            End If
        Next
    End If
    
    ' Clear spell casting
    ClearAccountSpellBuffer Index
    
    ' Sets it so we know to process npcs on the map
    PlayersOnMap(MapNum) = YES
    tempplayer(Index).GettingMap = YES
    Set buffer = New clsBuffer
    Call SendCheckForMap(Index, MapNum)
End Sub

Sub PlayerMove(ByVal Index As Long, ByVal Dir As Long, ByVal movement As Long, Optional ByVal SendToSelf As Boolean = False)
    Dim buffer As clsBuffer, MapNum As Integer
    Dim X As Long, Y As Long, i As Long
    Dim Moved As Byte, MovedSoFar As Boolean
    Dim TileType As Long, VitalType As Long, Color As Long, Amount As Long
    Dim NewMapY As Long, NewMapX As Long
    Dim NewMapNum As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or Dir < DIR_UP Or Dir > DIR_DOWNRIGHT Or movement < 1 Or movement > 2 Then Exit Sub
    
    ' Don't allow them to move if they are transfering to a new map
    If tempplayer(Index).GettingMap = YES Then Exit Sub
    
    ' Don't let them move if an event is waiting for their response
    If tempplayer(Index).EventProcessingCount > 0 Then
        For i = 1 To tempplayer(Index).EventProcessingCount
            If tempplayer(Index).EventProcessing(i).WaitingForResponse > 0 Then
                Call SendPlayerXY(Index)
                Exit Sub
            End If
        Next
    End If
    
    ' Prevent player from moving if they are casting a spell
    If tempplayer(Index).SpellBuffer.Spell > 0 Then Exit Sub
    
    ' If stunned, stop them moving
    If tempplayer(Index).StunDuration > 0 Then Exit Sub

    Call SetPlayerDir(Index, Dir)
    
    Moved = NO
    MapNum = GetPlayerMap(Index)
    
    Select Case Dir
        Case DIR_UPLEFT
            ' Check to make sure not outside of boundries
            If Map(GetPlayerMap(Index)).Up > 0 And GetPlayerY(Index) = 0 Then
                NewMapNum = Map(GetPlayerMap(Index)).Up
                NewMapX = GetPlayerX(Index)
                NewMapY = Map(NewMapNum).MaxY
            ElseIf Map(GetPlayerMap(Index)).Left > 0 And GetPlayerX(Index) = 0 Then
                NewMapNum = Map(GetPlayerMap(Index)).Left
                NewMapX = Map(Map(GetPlayerMap(Index)).Left).MaxX
                NewMapY = GetPlayerY(Index)
            ElseIf GetPlayerX(Index) - 1 > 0 And GetPlayerY(Index) - 1 > 0 Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_UP + 1) And Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_LEFT + 1) Then
                    If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) - 1, GetPlayerY(Index) - 1).Type <> TILE_TYPE_BLOCKED Then
                        If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) - 1, GetPlayerY(Index) - 1).Type <> TILE_TYPE_RESOURCE Then
                            Call SetPlayerY(Index, GetPlayerY(Index) - 1)
                            Call SetPlayerX(Index, GetPlayerX(Index) - 1)
                            SendPlayerMove Index, movement, SendToSelf
                            Moved = YES
                        End If
                    End If
                End If
            End If
            
            If Moved = NO Then
                ' Check to see if we can move them to the another map
                If NewMapNum > 0 Then
                    If GetPlayerMap(Index) <> NewMapNum Then
                        Call PlayerWarp(Index, NewMapNum, NewMapX, NewMapY)
                        Moved = YES
                        ' clear their target
                        tempplayer(Index).target = 0
                        tempplayer(Index).targetType = TARGET_TYPE_NONE
                        SendPlayerTarget Index
                    End If
                End If
            End If
            
        Case DIR_UPRIGHT
            ' Check to make sure not outside of boundries
            If Map(GetPlayerMap(Index)).Up > 0 And GetPlayerY(Index) = 0 Then
                NewMapNum = Map(GetPlayerMap(Index)).Up
                NewMapX = GetPlayerX(Index)
                NewMapY = Map(NewMapNum).MaxY
            ElseIf Map(GetPlayerMap(Index)).Right > 0 And GetPlayerX(Index) = Map(GetPlayerMap(Index)).MaxX Then
                NewMapNum = Map(GetPlayerMap(Index)).Right
                NewMapX = 0
                NewMapY = GetPlayerY(Index)
            ElseIf GetPlayerX(Index) + 1 <= Map(GetPlayerMap(Index)).MaxX And GetPlayerY(Index) - 1 > 0 Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_UP + 1) And Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_RIGHT + 1) Then
                    If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) + 1, GetPlayerY(Index) - 1).Type <> TILE_TYPE_BLOCKED Then
                        If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) + 1, GetPlayerY(Index) - 1).Type <> TILE_TYPE_RESOURCE Then
                            Call SetPlayerY(Index, GetPlayerY(Index) - 1)
                            Call SetPlayerX(Index, GetPlayerX(Index) + 1)
                            SendPlayerMove Index, movement, SendToSelf
                            Moved = YES
                        End If
                    End If
                End If
            End If
            
            ' Check to see if we can move them to the another map
            If Moved = NO Then
                If NewMapNum > 0 Then
                    Call PlayerWarp(Index, NewMapNum, NewMapX, NewMapY)
                    Moved = YES
                    ' clear their target
                    tempplayer(Index).target = 0
                    tempplayer(Index).targetType = TARGET_TYPE_NONE
                    SendPlayerTarget Index
                End If
            End If
            
        Case DIR_DOWNLEFT
            ' Check to make sure not outside of boundries
            If Map(GetPlayerMap(Index)).Down > 0 And GetPlayerY(Index) = Map(GetPlayerMap(Index)).MaxY Then
                NewMapNum = Map(GetPlayerMap(Index)).Down
                NewMapX = GetPlayerX(Index)
                NewMapY = 0
            ElseIf Map(GetPlayerMap(Index)).Left > 0 And GetPlayerX(Index) = 0 Then
                NewMapNum = Map(GetPlayerMap(Index)).Left
                NewMapX = Map(NewMapNum).MaxX
                NewMapY = GetPlayerY(Index)
            ElseIf GetPlayerX(Index) - 1 > 0 And GetPlayerY(Index) + 1 <= Map(GetPlayerMap(Index)).MaxY Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_DOWN + 1) And Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_LEFT + 1) Then
                    If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) - 1, GetPlayerY(Index) + 1).Type <> TILE_TYPE_BLOCKED Then
                        If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) - 1, GetPlayerY(Index) + 1).Type <> TILE_TYPE_RESOURCE Then
                            Call SetPlayerY(Index, GetPlayerY(Index) + 1)
                            Call SetPlayerX(Index, GetPlayerX(Index) - 1)
                            SendPlayerMove Index, movement, SendToSelf
                            Moved = YES
                        End If
                    End If
                End If
            End If
            
            ' Check to see if we can move them to the another map
            If Moved = NO Then
                If NewMapNum > 0 Then
                    If GetPlayerMap(Index) <> NewMapNum Then
                        Call PlayerWarp(Index, NewMapNum, NewMapX, NewMapY)
                        Moved = YES
                        ' clear their target
                        tempplayer(Index).target = 0
                        tempplayer(Index).targetType = TARGET_TYPE_NONE
                        SendPlayerTarget Index
                    End If
                End If
            End If
            
        Case DIR_DOWNRIGHT
            ' Check to make sure not outside of boundries
            If Map(GetPlayerMap(Index)).Down > 0 And GetPlayerY(Index) = Map(GetPlayerMap(Index)).MaxY Then
                NewMapNum = Map(GetPlayerMap(Index)).Down
                NewMapX = GetPlayerX(Index)
                NewMapY = 0
            ElseIf Map(GetPlayerMap(Index)).Right > 0 And GetPlayerX(Index) = Map(GetPlayerMap(Index)).MaxX Then
                NewMapNum = Map(GetPlayerMap(Index)).Right
                NewMapX = 0
                NewMapY = GetPlayerY(Index)
            ElseIf GetPlayerX(Index) + 1 <= Map(GetPlayerMap(Index)).MaxX And GetPlayerY(Index) + 1 <= Map(GetPlayerMap(Index)).MaxY Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_DOWN + 1) And Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_RIGHT + 1) Then
                    If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) + 1, GetPlayerY(Index) + 1).Type <> TILE_TYPE_BLOCKED Then
                        If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) + 1, GetPlayerY(Index) + 1).Type <> TILE_TYPE_RESOURCE Then
                            Call SetPlayerY(Index, GetPlayerY(Index) + 1)
                            Call SetPlayerX(Index, GetPlayerX(Index) + 1)
                            SendPlayerMove Index, movement, SendToSelf
                            Moved = YES
                        End If
                    End If
                End If
            End If
            
            ' Check to see if we can move them to the another map
            If Moved = NO Then
                If NewMapNum > 0 Then
                    If GetPlayerMap(Index) <> NewMapNum Then
                        Call PlayerWarp(Index, NewMapNum, NewMapX, NewMapY)
                        Moved = YES
                        ' clear their target
                        tempplayer(Index).target = 0
                        tempplayer(Index).targetType = TARGET_TYPE_NONE
                        SendPlayerTarget Index
                    End If
                End If
            End If
            
        Case DIR_UP
            ' Check to make sure not outside of boundries
            If GetPlayerY(Index) > 0 Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_UP + 1) Then
                    If Not IsPlayerBlocked(Index, 0, -1) Then
                        If Not IsEventBlocked(Index, 0, -1) Then
                            If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index) - 1).Type <> TILE_TYPE_BLOCKED Then
                                If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index) - 1).Type <> TILE_TYPE_RESOURCE Then
                                    Call SetPlayerY(Index, GetPlayerY(Index) - 1)
                                    SendPlayerMove Index, movement, SendToSelf
                                    Moved = YES
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                ' Check to see if we can move them to the another map
                If Map(GetPlayerMap(Index)).Up > 0 Then
                    If GetPlayerMap(Index) <> Map(GetPlayerMap(Index)).Up Then
                        Call PlayerWarp(Index, Map(GetPlayerMap(Index)).Up, GetPlayerX(Index), Map(Map(GetPlayerMap(Index)).Up).MaxY)
                        Moved = YES
                        
                        ' Clear their target
                        tempplayer(Index).target = 0
                        tempplayer(Index).targetType = TARGET_TYPE_NONE
                        SendPlayerTarget Index
                    End If
                End If
            End If

        Case DIR_DOWN
            ' Check to make sure not outside of boundries
            If GetPlayerY(Index) < Map(MapNum).MaxY Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_DOWN + 1) Then
                    If Not IsPlayerBlocked(Index, 0, 1) Then
                        If Not IsEventBlocked(Index, 0, 1) Then
                            If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index) + 1).Type <> TILE_TYPE_BLOCKED Then
                                If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index) + 1).Type <> TILE_TYPE_RESOURCE Then
                                    Call SetPlayerY(Index, GetPlayerY(Index) + 1)
                                    SendPlayerMove Index, movement, SendToSelf
                                    Moved = YES
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                ' Check to see if we can move them to the another map
                If Map(GetPlayerMap(Index)).Down > 0 Then
                    If GetPlayerMap(Index) <> Map(GetPlayerMap(Index)).Down Then
                        Call PlayerWarp(Index, Map(GetPlayerMap(Index)).Down, GetPlayerX(Index), 0)
                        Moved = YES
                        
                        ' Clear their target
                        tempplayer(Index).target = 0
                        tempplayer(Index).targetType = TARGET_TYPE_NONE
                        SendPlayerTarget Index
                    End If
                End If
            End If

        Case DIR_LEFT
            ' Check to make sure not outside of boundries
            If GetPlayerX(Index) > 0 Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_LEFT + 1) Then
                    If Not IsPlayerBlocked(Index, -1, 0) Then
                        If Not IsEventBlocked(Index, -1, 0) Then
                            If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) - 1, GetPlayerY(Index)).Type <> TILE_TYPE_BLOCKED Then
                                If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) - 1, GetPlayerY(Index)).Type <> TILE_TYPE_RESOURCE Then
                                    Call SetPlayerX(Index, GetPlayerX(Index) - 1)
                                    SendPlayerMove Index, movement, SendToSelf
                                    Moved = YES
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                ' Check to see if we can move them to the another map
                If Map(GetPlayerMap(Index)).Left > 0 Then
                    If GetPlayerMap(Index) <> Map(GetPlayerMap(Index)).Left Then
                    Call PlayerWarp(Index, Map(GetPlayerMap(Index)).Left, Map(Map(GetPlayerMap(Index)).Left).MaxX, GetPlayerY(Index))
                    Moved = YES
                    
                    ' Clear their target
                    tempplayer(Index).target = 0
                    tempplayer(Index).targetType = TARGET_TYPE_NONE
                    SendPlayerTarget Index
                    End If
                End If
            End If

        Case DIR_RIGHT
            ' Check to make sure not outside of boundries
            If GetPlayerX(Index) < Map(MapNum).MaxX Then
                ' Check to make sure that the tile is walkable
                If Not IsDirBlocked(Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index)).DirBlock, DIR_RIGHT + 1) Then
                    If Not IsPlayerBlocked(Index, 1, 0) Then
                        If Not IsEventBlocked(Index, 1, 0) Then
                            If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) + 1, GetPlayerY(Index)).Type <> TILE_TYPE_BLOCKED Then
                                If Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index) + 1, GetPlayerY(Index)).Type <> TILE_TYPE_RESOURCE Then
                                    Call SetPlayerX(Index, GetPlayerX(Index) + 1)
                                    SendPlayerMove Index, movement, SendToSelf
                                    Moved = YES
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                ' Check to see if we can move them to the another map
                If Map(GetPlayerMap(Index)).Right > 0 Then
                    If GetPlayerMap(Index) <> Map(GetPlayerMap(Index)).Right Then
                        Call PlayerWarp(Index, Map(GetPlayerMap(Index)).Right, 0, GetPlayerY(Index))
                        Moved = YES
                        
                        ' Clear their target
                        tempplayer(Index).target = 0
                        tempplayer(Index).targetType = TARGET_TYPE_NONE
                        SendPlayerTarget Index
                    End If
                End If
            End If
    End Select
    
    With Map(GetPlayerMap(Index)).Tile(GetPlayerX(Index), GetPlayerY(Index))
        ' Check to see if the tile is a warp tile, and if so warp them
        If .Type = TILE_TYPE_WARP Then
            MapNum = .Data1
            X = .Data2
            Y = .Data3
            Call PlayerWarp(Index, MapNum, X, Y)
            Moved = YES
        End If
        
        ' Check for a shop, and if so open it
        If .Type = TILE_TYPE_SHOP Then
            X = .Data1
            
            If X > 0 Then ' Shop exists?
                If Len(Trim$(Shop(X).Name)) > 0 Then ' Name exists?
                    SendOpenShop Index, X
                    tempplayer(Index).InShop = X ' Stops movement and the like
                End If
            End If
        End If
        
        ' Check to see if the tile is a bank, and if so send bank
        If .Type = TILE_TYPE_BANK Then
            SendBank Index
            tempplayer(Index).InBank = True
            Moved = YES
        End If
        
        ' Check if it's a heal tile
        If .Type = TILE_TYPE_HEAL Then
            VitalType = .Data1
            Amount = .Data2
            
            If VitalType = Int(Vitals.HP) Then
                Color = BrightGreen
            ElseIf VitalType = Int(Vitals.MP) Then
                Color = BrightBlue
            End If
            
            If Not GetPlayerVital(Index, VitalType) = GetPlayerMaxVital(Index, VitalType) Then
                If GetPlayerVital(Index, VitalType) + Amount > GetPlayerMaxVital(Index, VitalType) Then
                    Amount = GetPlayerMaxVital(Index, VitalType) - GetPlayerVital(Index, VitalType)
                End If
                SendActionMsg GetPlayerMap(Index), "+" & Amount, Color, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32, 1
                SetPlayerVital Index, VitalType, GetPlayerVital(Index, VitalType) + Amount
                Call SendVital(Index, VitalType)
            Else
                SendActionMsg GetPlayerMap(Index), "+0", Color, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32, 1
                If tempplayer(Index).InParty > 0 Then SendPartyVitals tempplayer(Index).InParty, Index
            End If
            Moved = YES
        End If
        
        ' Check if it's a trap tile
        If .Type = TILE_TYPE_TRAP Then
            VitalType = .Data1
            Amount = .Data2
            
            If VitalType = Int(Vitals.HP) Then
                Color = BrightRed
            ElseIf VitalType = Int(Vitals.MP) Then
                Color = Magenta
            End If
            
            If Not GetPlayerVital(Index, VitalType) < 1 Then
                If GetPlayerVital(Index, VitalType) - Amount < 1 Then
                    Amount = GetPlayerVital(Index, VitalType)
                End If
                SendActionMsg GetPlayerMap(Index), "-" & Amount, Color, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32, 1
                If GetPlayerVital(Index, HP) - Amount < 1 And VitalType = 1 Then
                    Call OnDeath(Index)
                    Call GlobalMsg(GetPlayerName(Index) & " has been killed by a trap!", BrightRed)
                Else
                    SetPlayerVital Index, VitalType, GetPlayerVital(Index, VitalType) - Amount
                    Call SendVital(Index, VitalType)
                End If
            Else
                SetPlayerVital Index, HP, GetPlayerVital(Index, HP) - Amount
                PlayerMsg Index, "You're injured by a trap.", BrightRed
                Call SendVital(Index, HP)
                ' Send vitals to party if in one
                If tempplayer(Index).InParty > 0 Then SendPartyVitals tempplayer(Index).InParty, Index
            End If
            Moved = YES
        End If
            
        ' Checkpoint
        If .Type = TILE_TYPE_CHECKPOINT Then
            SetCheckpoint Index, .Data1, .Data2, .Data3
            Moved = YES
        End If
        
        ' Slide
        If .Type = TILE_TYPE_SLIDE Then
            ForcePlayerMove Index, MOVING_WALKING, GetPlayerDir(Index)
            Moved = YES
        End If
    End With
    
    ' They tried to hack
    If Moved = NO Then
        Call PlayerWarp(Index, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
    Else
        X = GetPlayerX(Index)
        Y = GetPlayerY(Index)
    
        If Trim$(Account(Index).Chars(GetPlayerChar(Index)).Status) = "AFK" Then
            Account(Index).Chars(GetPlayerChar(Index)).Status = vbNullString
            Call SendPlayerStatus(Index)
        End If
        
        ' Check to see if events are touched
        EventTouch Index, X, Y
    End If
End Sub

Sub EventTouch(ByVal Index As Long, ByVal X As Long, ByVal Y As Long)
    Dim EventTouched As Boolean, i As Long
    
    If tempplayer(Index).EventMap.CurrentEvents > 0 Then
            For i = 1 To tempplayer(Index).EventMap.CurrentEvents
                If Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).Global = 1 Then
                    If Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).X = X And Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).Y = Y And Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).Pages(tempplayer(Index).EventMap.EventPages(i).PageID).Trigger = 1 And tempplayer(Index).EventMap.EventPages(i).Visible = 1 Then EventTouched = True
                Else
                    If tempplayer(Index).EventMap.EventPages(i).X = X And tempplayer(Index).EventMap.EventPages(i).Y = Y And Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).Pages(tempplayer(Index).EventMap.EventPages(i).PageID).Trigger = 1 And tempplayer(Index).EventMap.EventPages(i).Visible = 1 Then EventTouched = True
                End If
                
                If EventTouched Then
                    ' Process this event, it is on-touch and everything checks out.
                    If Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).Pages(tempplayer(Index).EventMap.EventPages(i).PageID).CommandListCount > 0 Then
                        tempplayer(Index).EventProcessingCount = tempplayer(Index).EventProcessingCount + 1
                        ReDim Preserve tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount)
                        tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).ActionTimer = timeGetTime
                        tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).CurList = 1
                        tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).CurSlot = 1
                        tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).eventID = tempplayer(Index).EventMap.EventPages(i).eventID
                        tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).PageID = tempplayer(Index).EventMap.EventPages(i).PageID
                        tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).WaitingForResponse = 0
                        ReDim tempplayer(Index).EventProcessing(tempplayer(Index).EventProcessingCount).ListLeftOff(0 To Map(GetPlayerMap(Index)).Events(tempplayer(Index).EventMap.EventPages(i).eventID).Pages(tempplayer(Index).EventMap.EventPages(i).PageID).CommandListCount)
                    End If
                    
                    EventTouched = False
                End If
            Next
        End If
End Sub

Sub ForcePlayerMove(ByVal Index As Long, ByVal movement As Long, ByVal Direction As Long)
    If Direction < DIR_UP Or Direction > DIR_DOWNRIGHT Then Exit Sub
    If movement < 1 Or movement > 2 Then Exit Sub

    Select Case Direction
        Case DIR_UP
            If GetPlayerY(Index) = 0 Then Exit Sub
        Case DIR_LEFT
            If GetPlayerX(Index) = 0 Then Exit Sub
        Case DIR_DOWN
            If GetPlayerY(Index) = Map(GetPlayerMap(Index)).MaxY Then Exit Sub
        Case DIR_RIGHT
            If GetPlayerX(Index) = Map(GetPlayerMap(Index)).MaxX Then Exit Sub
        Case DIR_UPLEFT
            If GetPlayerY(Index) = 0 And GetPlayerX(Index) = 0 Then Exit Sub
        Case DIR_UPRIGHT
            If GetPlayerY(Index) = 0 And GetPlayerX(Index) = Map(GetPlayerMap(Index)).MaxX Then Exit Sub
        Case DIR_DOWNLEFT
            If GetPlayerY(Index) = Map(GetPlayerMap(Index)).MaxY And GetPlayerX(Index) = 0 Then Exit Sub
        Case DIR_DOWNRIGHT
            If GetPlayerY(Index) = Map(GetPlayerMap(Index)).MaxY And GetPlayerX(Index) = Map(GetPlayerMap(Index)).MaxX Then Exit Sub
    End Select

    PlayerMove Index, Direction, movement, True
End Sub

Sub CheckEquippedItems(ByVal Index As Long)
    Dim Slot As Long
    Dim ItemNum As Integer
    Dim i As Long

    ' We want to check incase an admin takes away an object but they had it equipped
    For i = 1 To Equipment.Equipment_Count - 1
        ItemNum = GetPlayerEquipment(Index, i)

        If ItemNum > 0 Then
            If Not Item(ItemNum).Type = ITEM_TYPE_EQUIPMENT Or Not Item(ItemNum).EquipSlot = i Then SetPlayerEquipment Index, 0, i
        Else
            SetPlayerEquipment Index, 0, i
        End If
    Next
End Sub

Function FindOpenInvSlot(ByVal Index As Long, ByVal ItemNum As Long) As Long
    Dim i As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum <= 0 Or ItemNum > MAX_ITEMS Then Exit Function

    If Item(ItemNum).stackable = 1 Then
        ' If currency then check to see if they already have an instance of the item and add it to that
        For i = 1 To MAX_INV
            If GetPlayerInvItemNum(Index, i) = ItemNum Then
                FindOpenInvSlot = i
                Exit Function
            End If
        Next

    End If

    For i = 1 To MAX_INV
        ' Try to find an open free slot
        If GetPlayerInvItemNum(Index, i) = 0 Then
            FindOpenInvSlot = i
            Exit Function
        End If
    Next
End Function

Function FindOpenBankSlot(ByVal Index As Long, ByVal ItemNum As Integer) As Byte
    Dim i As Long

    ' Check for subscript out of range
    If Not IsPlaying(Index) Or ItemNum < 1 Or ItemNum > MAX_ITEMS Then Exit Function

    If Not Item(ItemNum).Type = ITEM_TYPE_EQUIPMENT Then
        For i = 1 To MAX_BANK
            If GetPlayerBankItemNum(Index, i) = ItemNum Then
                FindOpenBankSlot = i
                Exit Function
            End If
        Next
    End If

    For i = 1 To MAX_BANK
        If GetPlayerBankItemNum(Index, i) = 0 Then
            FindOpenBankSlot = i
            Exit Function
        End If
    Next
End Function

Function CheckBankSlots(ByVal Index As Long, ByVal ItemNum As Integer) As Long
    Dim i As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum < 1 Or ItemNum > MAX_ITEMS Then Exit Function

    For i = 1 To MAX_BANK
        ' Check to see if the player has the item
        If GetPlayerBankItemNum(Index, i) = ItemNum Then
            CheckBankSlots = CheckBankSlots + 1
        End If
    Next
End Function

Function CheckInventorySlots(ByVal Index As Long, ByVal ItemNum As Integer) As Long
    Dim i As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum < 1 Or ItemNum > MAX_ITEMS Then Exit Function

    For i = 1 To MAX_INV
        ' Check to see if the player has the item
        If GetPlayerInvItemNum(Index, i) = ItemNum Then
            CheckInventorySlots = CheckInventorySlots + 1
        End If
    Next
End Function

Function HasItem(ByVal Index As Long, ByVal ItemNum As Integer) As Long
    Dim i As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum < 1 Or ItemNum > MAX_ITEMS Then Exit Function

    For i = 1 To MAX_INV
        ' Check to see if the player has the item
        If GetPlayerInvItemNum(Index, i) = ItemNum Then
            If Item(ItemNum).stackable = 1 Then
                HasItem = GetPlayerInvItemValue(Index, i)
                Exit Function
            End If
        End If
    Next
End Function

Function TakeInvItem(ByVal Index As Long, ByVal ItemNum As Integer, ByVal ItemVal As Long, Optional Update As Boolean = True) As Boolean
    Dim i As Long, II As Long, NPCNum As Long
    Dim n As Long
    Dim Parse() As String

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum <= 0 Or ItemNum > MAX_ITEMS Then Exit Function

    For i = 1 To MAX_INV
        ' Check to see if the player has the item
        If GetPlayerInvItemNum(Index, i) = ItemNum Then
            If Item(ItemNum).stackable = 1 Then
                ' Is what we are trying to take away more then what they have?  If so just set it to zero
                If ItemVal >= GetPlayerInvItemValue(Index, i) Then
                    TakeInvItem = True
                Else
                    Call SetPlayerInvItemValue(Index, i, GetPlayerInvItemValue(Index, i) - ItemVal)
                    
                    If Update Then Call SendInventoryUpdate(Index, i)
                    
                    'check quests
                    For II = 1 To MAX_QUESTS
                        Parse() = Split(HasQuestItems(Index, II, True), "|")
                        If UBound(Parse()) > 0 Then
                            NPCNum = Parse(0)
                            If NPCNum > 0 Then
                                Call SendShowTaskCompleteOnNPC(Index, NPCNum, False)
                            End If
                        End If
                    Next II
                    
                    Exit Function
                End If
            Else
                TakeInvItem = True
            End If

            If TakeInvItem Then
                Call SetPlayerInvItemNum(Index, i, 0)
                Call SetPlayerInvItemValue(Index, i, 0)
                Call SetPlayerInvItemDur(Index, i, 0)
                Call SetPlayerInvItemBind(Index, i, 0)
                Exit For
            End If
        End If
    Next
    
    'check quests
    For II = 1 To MAX_QUESTS
        Parse() = Split(HasQuestItems(Index, II, True), "|")
        If UBound(Parse()) > 0 Then
            NPCNum = Parse(0)
            If NPCNum > 0 Then
                Call SendShowTaskCompleteOnNPC(Index, NPCNum, False)
            End If
        End If
    Next II
    
    ' Send the inventory update
    If Update Then Call SendInventory(Index)
End Function

Function TakeInvSlot(ByVal Index As Long, ByVal InvSlot As Byte, ByVal ItemVal As Long, Optional ByVal Update As Boolean = True) As Boolean
    Dim i As Long
    Dim n As Long
    Dim ItemNum As Integer

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or InvSlot < 1 Or InvSlot > MAX_ITEMS Then Exit Function
    
    ItemNum = GetPlayerInvItemNum(Index, InvSlot)

    ' Prevent subscript out of range
    If ItemNum < 1 Then Exit Function
    
    If Item(ItemNum).stackable = 1 Then
        ' Is what we are trying to take away more then what they have?  If so just set it to zero
        If ItemVal >= GetPlayerInvItemValue(Index, InvSlot) Then
            TakeInvSlot = True
        Else
            Call SetPlayerInvItemValue(Index, InvSlot, GetPlayerInvItemValue(Index, InvSlot) - ItemVal)
            
            ' Send the inventory update
            If Update Then
                Call SendInventoryUpdate(Index, InvSlot)
            End If
            Exit Function
        End If
    Else
        TakeInvSlot = True
    End If

    If TakeInvSlot Then
        Call SetPlayerInvItemNum(Index, InvSlot, 0)
        Call SetPlayerInvItemValue(Index, InvSlot, 0)
        Call SetPlayerInvItemDur(Index, InvSlot, 0)
        Call SetPlayerInvItemBind(Index, InvSlot, 0)
        
        ' Send the inventory update
        If Update Then
            Call SendInventoryUpdate(Index, InvSlot)
        End If
    End If
End Function

Function GiveInvItem(ByVal Index As Long, ByVal ItemNum As Integer, ByVal ItemVal As Long, Optional ByVal ItemDur As Integer = -1, Optional ByVal ItemBind As Integer = 0, Optional ByVal SendUpdate As Boolean = True) As Byte
    Dim i As Long, II As Long, NPCNum As Long, X As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum <= 0 Or ItemNum > MAX_ITEMS Then Exit Function

    i = FindOpenInvSlot(Index, ItemNum)

    ' Check to see if inventory is full
    If i > 0 And i <= MAX_INV Then
        If CDec(GetPlayerInvItemValue(Index, i)) + CDec(ItemVal) > 2147483468 Then
            Call PlayerMsg(Index, "Cannot give it to you, it exceeds the maximum limit!", BrightRed)
            Exit Function
        Else
            Call SetPlayerInvItemNum(Index, i, ItemNum)
            
            If Item(ItemNum).stackable = 1 Then
                Call SetPlayerInvItemValue(Index, i, GetPlayerInvItemValue(Index, i) + ItemVal)
            Else
                If Item(ItemNum).Type <> ITEM_TYPE_EQUIPMENT Then
                    Call SetPlayerInvItemValue(Index, i, 1)
                ElseIf ItemVal = 0 Then
                    ItemVal = 1
                End If
                
                For X = 1 To ItemVal - 1
                    II = FindOpenInvSlot(Index, ItemNum)
                    
                    If II > 0 And II <= MAX_INV Then
                        Call SetPlayerInvItemNum(Index, II, ItemNum)
                        If Item(ItemNum).Type <> ITEM_TYPE_EQUIPMENT Then Call SetPlayerInvItemValue(Index, II, 1)
                        
                        If Item(GetPlayerInvItemNum(Index, II)).Type = ITEM_TYPE_EQUIPMENT Then
                            If ItemDur = -1 Then
                                Call SetPlayerInvItemDur(Index, II, Item(ItemNum).Data1)
                            Else
                                Call SetPlayerInvItemDur(Index, II, ItemDur)
                            End If
                        End If
                        
                        If ItemBind = BIND_ON_PICKUP Or Item(GetPlayerInvItemNum(Index, II)).BindType = BIND_ON_PICKUP Then
                            Call SetPlayerInvItemBind(Index, II, BIND_ON_PICKUP)
                        ElseIf ItemBind = BIND_ON_EQUIP Or Item(GetPlayerInvItemNum(Index, II)).BindType = BIND_ON_EQUIP Then
                            Call SetPlayerInvItemBind(Index, II, BIND_ON_EQUIP)
                        Else
                            Call SetPlayerInvItemBind(Index, II, 0)
                        End If
                        
                        If SendUpdate Then Call SendInventoryUpdate(Index, II)
                    Else
                        For II = X To ItemVal - 1
                            If Item(ItemNum).Type <> ITEM_TYPE_EQUIPMENT Then
                                If ItemDur = -1 Then
                                    Call SpawnItem(ItemNum, 1, Item(ItemNum).Data1, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
                                Else
                                    Call SpawnItem(ItemNum, 1, ItemDur, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
                                End If
                            Else
                                If ItemDur = -1 Then
                                    Call SpawnItem(ItemNum, 0, Item(ItemNum).Data1, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
                                Else
                                    Call SpawnItem(ItemNum, 0, ItemDur, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
                                End If
                            End If
                        Next
                        
                        Call PlayerMsg(Index, "Your inventory is full!", BrightRed)
                        Exit For
                    End If
                Next
            End If
        End If
        
        If Item(GetPlayerInvItemNum(Index, i)).Type = ITEM_TYPE_EQUIPMENT Then
            If ItemDur = -1 Then
                Call SetPlayerInvItemDur(Index, i, Item(ItemNum).Data1)
            Else
                Call SetPlayerInvItemDur(Index, i, ItemDur)
            End If
        End If
        
        If ItemBind = BIND_ON_PICKUP Or Item(GetPlayerInvItemNum(Index, i)).BindType = BIND_ON_PICKUP Then
            Call SetPlayerInvItemBind(Index, i, BIND_ON_PICKUP)
        ElseIf ItemBind = BIND_ON_EQUIP Or Item(GetPlayerInvItemNum(Index, i)).BindType = BIND_ON_EQUIP Then
            Call SetPlayerInvItemBind(Index, i, BIND_ON_EQUIP)
        Else
            Call SetPlayerInvItemBind(Index, i, 0)
        End If
        
        If SendUpdate Then Call SendInventoryUpdate(Index, i)
        GiveInvItem = True
        
        'check quests
        For II = 1 To MAX_QUESTS
            NPCNum = HasQuestItems(Index, II)
            If NPCNum > 0 Then
                Call SendShowTaskCompleteOnNPC(Index, NPCNum, True)
            End If
        Next II
    Else
        Call PlayerMsg(Index, "Your inventory is full!", BrightRed)
    End If
    
    GiveInvItem = i
End Function

Function HasSpell(ByVal Index As Long, ByVal SpellNum As Long) As Boolean
    Dim i As Long

    For i = 1 To MAX_PLAYER_SPELLS
        If GetPlayerSpell(Index, i) = SpellNum Then
            HasSpell = True
            Exit Function
        End If
    Next
End Function

Function FindOpenSpellSlot(ByVal Index As Long) As Long
    Dim i As Long

    For i = 1 To MAX_PLAYER_SPELLS
        If GetPlayerSpell(Index, i) = 0 Then
            FindOpenSpellSlot = i
            Exit Function
        End If
    Next
End Function

Sub PlayerMapGetItem(ByVal Index As Long, ByVal i As Long)
    Dim n As Long
    Dim MapNum As Integer
    Dim Msg As String
    Dim tempVal As Variant
    Dim ItemNum As Long, Value As Long, Dur As Long, Bind As Long
    
    ' Check for subscript out of range
    If Not IsPlaying(Index) Then Exit Sub
    
    MapNum = GetPlayerMap(Index)

    ' See if there's even an item here
    If (MapItem(MapNum, i).Num > 0) And (MapItem(MapNum, i).Num <= MAX_ITEMS) Then
        ' Can we pick the item up?
        If CanPlayerPickupItem(Index, i) Then
            ' Check if item is at the same location as the player
            If (MapItem(MapNum, i).X = GetPlayerX(Index)) Then
                If (MapItem(MapNum, i).Y = GetPlayerY(Index)) Then
                    ItemNum = MapItem(MapNum, i).Num
                    Value = MapItem(MapNum, i).Value
                    Dur = MapItem(MapNum, i).Durability
                    Bind = Item(ItemNum).BindType
                    If Value > 0 Then
                        Msg = Value & " " & Trim$(Item(ItemNum).Name)
                    Else
                        Msg = Trim$(Item(ItemNum).Name)
                    End If
                    
                    'sure made this a lot simpler than it was, removing roughly 30 lines of code in exchange for 5.  It could be done in 1 line
                    'but I chose to make it pretty and easy to debug had something went wrong.
                    Call GiveInvItem(Index, ItemNum, Value, Dur, Bind, True)
                    
                    ' Erase the item from the map
                    MapItem(MapNum, i).Num = 0
                    MapItem(MapNum, i).Value = 0
                    MapItem(MapNum, i).Durability = 0
                    MapItem(MapNum, i).X = 0
                    MapItem(MapNum, i).Y = 0
                    
                    Call SendInventoryUpdate(Index, n)
                    Call SpawnItemSlot(i, 0, 0, 0, GetPlayerMap(Index), 0, 0)
                    SendActionMsg GetPlayerMap(Index), Msg, Yellow, 1, (GetPlayerX(Index) * 32), (GetPlayerY(Index) * 32)
                End If
            End If
        End If
    End If
End Sub

Public Function CanPlayerPickupItem(ByVal Index As Long, ByVal MapItemNum As Integer, Optional ByVal ItemVal As Long = 1)
    Dim MapNum As Integer

    MapNum = GetPlayerMap(Index)
    
    ' Check for subscript out of range
    If MapNum < 1 Or MapNum > MAX_MAPS Then Exit Function
    
    If Moral(Map(MapNum).Moral).CanPickupItem = 1 Then
        ' No lock or locked to player?
        If Trim$(MapItem(MapNum, MapItemNum).playerName) = vbNullString Or Trim$(MapItem(MapNum, MapItemNum).playerName) = GetPlayerName(Index) Then
            CanPlayerPickupItem = True
            Exit Function
        End If
    End If
End Function

Sub PlayerMapDropItem(ByVal Index As Long, ByVal InvNum As Byte, ByVal Amount As Long)
    Dim i As Long
    Dim Msg As String
    
    If (GetPlayerInvItemNum(Index, InvNum) <= MAX_ITEMS) Then
        i = FindOpenMapItemSlot(GetPlayerMap(Index))

        If Not i = 0 Then
            MapItem(GetPlayerMap(Index), i).Num = GetPlayerInvItemNum(Index, InvNum)
            MapItem(GetPlayerMap(Index), i).X = GetPlayerX(Index)
            MapItem(GetPlayerMap(Index), i).Y = GetPlayerY(Index)
            MapItem(GetPlayerMap(Index), i).playerName = Trim$(GetPlayerName(Index))
            MapItem(GetPlayerMap(Index), i).PlayerTimer = timeGetTime + ITEM_SPAWN_TIME
            MapItem(GetPlayerMap(Index), i).CanDespawn = True
            MapItem(GetPlayerMap(Index), i).DespawnTimer = timeGetTime + ITEM_DESPAWN_TIME

            If Item(GetPlayerInvItemNum(Index, InvNum)).Type = ITEM_TYPE_EQUIPMENT Then
                MapItem(GetPlayerMap(Index), i).Durability = GetPlayerInvItemDur(Index, InvNum)
            Else
                MapItem(GetPlayerMap(Index), i).Durability = 0
            End If
            
            If Item(GetPlayerInvItemNum(Index, InvNum)).stackable = 1 Then
                ' Check if its more then they have and if so drop it all
                If Amount >= GetPlayerInvItemValue(Index, InvNum) Then
                    MapItem(GetPlayerMap(Index), i).Value = GetPlayerInvItemValue(Index, InvNum)
                    Msg = GetPlayerInvItemValue(Index, InvNum) & " " & Trim$(Item(GetPlayerInvItemNum(Index, InvNum)).Name)
                    
                    Call TakeInvSlot(Index, InvNum, GetPlayerInvItemValue(Index, InvNum), True)
                Else
                    MapItem(GetPlayerMap(Index), i).Value = Amount
                    Msg = Amount & " " & Trim$(Item(GetPlayerInvItemNum(Index, InvNum)).Name)
                    Call TakeInvSlot(Index, InvNum, Amount, True)
                End If
            Else
                ' It's not a currency object so this is easy
                Msg = Trim$(Item(GetPlayerInvItemNum(Index, InvNum)).Name)
                MapItem(GetPlayerMap(Index), i).Value = 0
                Call TakeInvSlot(Index, InvNum, Amount, True)
            End If
            
            ' Send message
            SendActionMsg GetPlayerMap(Index), Msg, BrightRed, 1, (GetPlayerX(Index) * 32), (GetPlayerY(Index) * 32)

            ' Spawn the item before we set the num or we'll get a different free map item slot
            Call SpawnItemSlot(i, MapItem(GetPlayerMap(Index), i).Num, Amount, MapItem(GetPlayerMap(Index), i).Durability, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
        Else
            Call PlayerMsg(Index, "There are too many items on the ground to drop anything else.", BrightRed)
        End If
    End If
End Sub

Sub CheckPlayerLevelUp(ByVal Index As Long)
    Dim i As Long
    Dim ExpRollOver As Long
    Dim Level_Count As Long

    If GetPlayerLevel(Index) > 0 And GetPlayerLevel(Index) < Options.MaxLevel Then
        Do While GetPlayerExp(Index) >= GetPlayerNextLevel(Index)
            ExpRollOver = GetPlayerExp(Index) - GetPlayerNextLevel(Index)
            Call SetPlayerLevel(Index, GetPlayerLevel(Index) + 1)
            Call SetPlayerPoints(Index, GetPlayerPoints(Index) + Options.StatsLevel)
            Call SetPlayerExp(Index, ExpRollOver)
            Level_Count = Level_Count + 1
        Loop
        
        If Level_Count > 0 Then
            Call SendAnimation(GetPlayerMap(Index), Options.LevelUpAnimation, 0, 0, TARGET_TYPE_PLAYER, Index)
            SendPlayerExp Index
            
            If Level_Count > 1 Then
                Call GlobalMsg(GetPlayerName(Index) & " has gained " & Level_Count & " levels!", Yellow)
            Else
                Call GlobalMsg(GetPlayerName(Index) & " has gained a level!", Yellow)
            End If
            
            ' Restore and send vitals
            For i = 1 To Vitals.Vital_Count - 1
                Call SetPlayerVital(Index, i, GetPlayerMaxVital(Index, i))
                Call SendVital(Index, i)
            Next
            
            ' Check for new title
            Call CheckPlayerNewTitle(Index)
            
            ' Check if any of the player's spells can rank up
            For i = 1 To MAX_PLAYER_SPELLS
                If GetPlayerSpell(Index, i) > 0 Then
                    If Spell(GetPlayerSpell(Index, i)).NewSpell > 0 Then
                        If Spell(Spell(GetPlayerSpell(Index, i)).NewSpell).CastRequired > 0 Then
                            Call CheckSpellRankUp(Index, GetPlayerSpell(Index, i), i)
                        End If
                    End If
                End If
            Next
            
            ' Send other data
            Call SendPlayerStats(Index)
            Call SendPlayerPoints(Index)
            Call SendPlayerLevel(Index)
        End If
    End If
End Sub

Sub CheckPlayerSkillLevelUp(ByVal Index As Long, ByVal SkillNum As Byte)
    Dim ExpRollOver As Long
    Dim Level_Count As Long
    
    Level_Count = 0

    If GetPlayerSkill(Index, SkillNum) > 0 And GetPlayerSkill(Index, SkillNum) < Options.MaxLevel Then
        Do While GetPlayerSkillExp(Index, SkillNum) >= GetPlayerNextSkillLevel(Index, SkillNum)
            ExpRollOver = GetPlayerSkillExp(Index, SkillNum) - GetPlayerNextSkillLevel(Index, SkillNum)
            Call SetPlayerSkill(Index, GetPlayerSkill(Index, SkillNum) + 1, SkillNum)
            Call SetPlayerSkillExp(Index, ExpRollOver, SkillNum)
            Level_Count = Level_Count + 1
        Loop
        
        If Level_Count > 0 Then
            Call SendAnimation(GetPlayerMap(Index), Options.LevelUpAnimation, 0, 0, TARGET_TYPE_PLAYER, Index)
            Call PlayerMsg(Index, "Your " & CheckGrammar(GetSkillName(SkillNum)) & " level is now " & GetPlayerSkill(Index, SkillNum) & ".", BrightGreen)
        End If
    End If
End Sub

Private Function AutoLife(ByVal Index As Long) As Boolean
    Dim i As Byte
    
    For i = 1 To MAX_INV
        If GetPlayerInvItemNum(Index, i) > 0 Then
            If Item(GetPlayerInvItemNum(Index, i)).Type = ITEM_TYPE_AUTOLIFE Then
                If CanPlayerUseItem(Index, GetPlayerInvItemNum(Index, i), False) Then
                    ' HP
                    If Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddHP > 0 Then
                        If Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddHP > GetPlayerMaxVital(Index, HP) Then
                            SendActionMsg GetPlayerMap(Index), "+" & GetPlayerMaxVital(Index, HP), BrightGreen, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
                        Else
                            SendActionMsg GetPlayerMap(Index), "+" & Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddHP, BrightGreen, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
                        End If
                        Call SetPlayerVital(Index, Vitals.HP, GetPlayerVital(Index, Vitals.HP) + Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddHP)
                        Call SendVital(Index, Vitals.HP)
                    End If
                    
                    ' MP
                    If Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddMP > 0 Then
                        If Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddMP > GetPlayerMaxVital(Index, MP) Then
                            SendActionMsg GetPlayerMap(Index), "+" & GetPlayerMaxVital(Index, MP), BrightBlue, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
                        Else
                            SendActionMsg GetPlayerMap(Index), "+" & Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddMP, BrightBlue, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
                        End If
                        Call SendVital(Index, Vitals.MP)
                        Call SetPlayerVital(Index, Vitals.MP, GetPlayerVital(Index, Vitals.MP) + Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).AddMP)
                    End If
                    
                    ' If it is not reusable then take the item away
                    If Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).IsReusable = False Then
                        Call TakeInvItem(Index, Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num, 0)
                    End If
                    
                    Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, i)).Animation, 0, 0, TARGET_TYPE_PLAYER, Index)
                    
                    ' Warp player away
                    If Item(Account(Index).Chars(GetPlayerChar(Index)).Inv(i).Num).Data1 = 1 Then
                        Call WarpPlayer(Index)
                    End If
                    
                    Call PlayerMsg(Index, "You have been given another life!", Yellow)
                    
                    AutoLife = True
                    Exit Function
                End If
            End If
        End If
    Next
End Function

Sub OnDeath(ByVal Index As Long, Optional ByVal Attacker As Long = 0)
    Dim i As Long, RemoveItem As Boolean
   
    ' Set HP to 0
    Call SetPlayerVital(Index, Vitals.HP, 0)
    
    ' Exit out if they were saved
    If AutoLife(Index) Then Exit Sub
    
    ' If map moral can drop items or not
    If Moral(Map(GetPlayerMap(Index)).Moral).DropItems = 1 Or GetPlayerPK(Index) = PLAYER_KILLER Or (GetPlayerPK(Index) = PLAYER_DEFENDER And GetPlayerPK(Attacker) = PLAYER_KILLER) Then
        If GetPlayerPK(Index) <> NO Then
            Call SetPlayerPK(Index, NO)
            Call SendPlayerPK(Index)
        End If

        ' Drop all worn items
        For i = 1 To Equipment.Equipment_Count - 1
            RemoveItem = False
            
            If GetPlayerEquipment(Index, i) > 0 Then
                If tempplayer(Index).InParty > 0 Then
                    Call Party_GetLoot(tempplayer(Attacker).InParty, GetPlayerEquipment(Index, i), 1, GetPlayerX(Index), GetPlayerY(Index))
                    RemoveItem = True
                Else
                    If Moral(Map(GetPlayerMap(Index)).Moral).CanDropItem = 1 Then
                        If Attacker > 0 Then
                            Call SpawnItem(GetPlayerEquipment(Index, i), 1, 0, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index), GetPlayerName(Attacker))
                            RemoveItem = True
                        Else
                            Call SpawnItem(GetPlayerEquipment(Index, i), 1, 0, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index))
                            RemoveItem = True
                        End If
                    Else
                        If Attacker > 0 Then
                            Call GiveInvItem(Attacker, GetPlayerEquipment(Index, i), 1)
                            RemoveItem = True
                        End If
                    End If
                End If
                            
                ' Remove equipment item
                If RemoveItem Then
                    ' Send a message to the world indicating that they dropped an item
                    Call GlobalMsg(GetPlayerName(Index) & " drops " & CheckGrammar(Trim$(Item(GetPlayerEquipment(Index, i)).Name)) & "!", Yellow)
                    
                    SetPlayerEquipment Index, 0, i
                    SetPlayerEquipmentDur Index, 0, i
                    SetPlayerEquipmentBind Index, 0, i
                End If
            End If
        Next
        
        ' Drop 10% of their Gold
        For i = 1 To MAX_INV
            If GetPlayerInvItemNum(Index, i) = 1 Then
                If Round(GetPlayerInvItemValue(Index, i) / 10) > 0 Then
                    Call TakeInvItem(Index, GetPlayerInvItemNum(Index, i), Round(GetPlayerInvItemValue(Index, i) / 10))
                    Call SpawnItem(1, Round(GetPlayerInvItemValue(Index, i) / 10), 0, GetPlayerMap(Index), GetPlayerX(Index), GetPlayerY(Index), GetPlayerName(Attacker))
                    Exit For
                End If
            End If
        Next
    
        ' Add the player kill
        If Attacker > 0 Then Account(FindPlayer(GetPlayerName(Attacker))).Chars(GetPlayerChar(i)).PlayerKills = Account(FindPlayer(GetPlayerName(Attacker))).Chars(GetPlayerChar(i)).PlayerKills + 1
        
        ' Check for new title
        Call CheckPlayerNewTitle(Index)
    End If
    
    ' Loop through entire map and purge npc targets from player
    For i = 1 To Map(GetPlayerMap(Index)).NPC_HighIndex
        If MapNPC(GetPlayerMap(Index)).NPC(i).Num > 0 Then
            If MapNPC(GetPlayerMap(Index)).NPC(i).targetType = TARGET_TYPE_PLAYER Then
                If MapNPC(GetPlayerMap(Index)).NPC(i).target = Index Then
                    MapNPC(GetPlayerMap(Index)).NPC(i).target = 0
                    MapNPC(GetPlayerMap(Index)).NPC(i).targetType = TARGET_TYPE_NONE
                    Call SendMapNPCTarget(GetPlayerMap(Index), i, 0, 0)
                End If
            End If
        End If
    Next

    ' Set player direction
    Call SetPlayerDir(Index, DIR_DOWN)
    
    ' Warp away player
    Call WarpPlayer(Index)
    
    ' Clear all DoTs and HoTs
    For i = 1 To MAX_DOTS
        With tempplayer(Index).DoT(i)
            .Used = False
            .Spell = 0
            .Timer = 0
            .Caster = 0
            .StartTime = 0
        End With
        
        With tempplayer(Index).HoT(i)
            .Used = False
            .Spell = 0
            .Timer = 0
            .Caster = 0
            .StartTime = 0
        End With
    Next
    
    ' Clear spell casting
    Call ClearAccountSpellBuffer(Index)
    
    ' Restore vitals
    Call SetPlayerVital(Index, Vitals.HP, GetPlayerMaxVital(Index, Vitals.HP))
    Call SetPlayerVital(Index, Vitals.MP, GetPlayerMaxVital(Index, Vitals.MP))

    ' Send vitals to party if in one
    If tempplayer(Index).InParty > 0 Then SendPartyVitals tempplayer(Index).InParty, Index
    
    ' Send vitals
    For i = 1 To Vitals.Vital_Count - 1
        Call SendVital(Index, i)
    Next
End Sub

Private Sub WarpPlayer(ByVal Index As Long)
     With Map(GetPlayerMap(Index))
        If .BootMap = 0 Then
            ' Warp to the checkpoint
            Call WarpToCheckPoint(Index)
        Else
            ' Warp to the boot map
            If .BootMap > 0 And .BootMap <= MAX_MAPS Then
                PlayerWarp Index, .BootMap, .BootX, .BootY
            Else
                ' Warp to the start map
                Call PlayerWarp(Index, Class(GetPlayerClass(Index)).Map, Class(GetPlayerClass(Index)).X, Class(GetPlayerClass(Index)).Y, False, Class(GetPlayerClass(Index)).Dir)
            End If
        End If
     End With
End Sub

Sub CheckResource(ByVal Index As Long, ByVal X As Long, ByVal Y As Long)
    Dim Resource_Num As Long
    Dim Resource_Index As Long
    Dim rX As Long, rY As Long
    Dim i As Long
    Dim Damage As Long
    Dim RndNum As Long
    
    If Map(GetPlayerMap(Index)).Tile(X, Y).Type = TILE_TYPE_RESOURCE Then
        Resource_Num = 0
        Resource_Index = Map(GetPlayerMap(Index)).Tile(X, Y).Data1

        ' Get the cache number
        For i = 0 To ResourceCache(GetPlayerMap(Index)).Resource_Count
            If ResourceCache(GetPlayerMap(Index)).ResourceData(i).X = X Then
                If ResourceCache(GetPlayerMap(Index)).ResourceData(i).Y = Y Then
                    Resource_Num = i
                End If
            End If
        Next

        If Resource_Num > 0 Then
            ' Check if they meet the level required
            If Resource(Resource_Index).LevelReq > 0 Then
                If GetPlayerSkill(Index, Resource(Resource_Index).Skill) < Resource(Resource_Index).LevelReq Then
                    Call PlayerMsg(Index, "Your " & CheckGrammar(GetSkillName(Resource(Resource_Index).LevelReq)) & " skill level does not meet the requirement to use this resource!", BrightRed)
                    Exit Sub
                End If
            End If
            
            ' Check if they have the right tool
            If Resource(Resource_Index).ToolRequired > 0 Then
                If GetPlayerEquipment(Index, Weapon) < 1 Then
                    PlayerMsg Index, "You need a tool to interact with this resource!", BrightRed
                    Exit Sub
                End If
                
                If Item(GetPlayerEquipment(Index, Weapon)).Tool <> Resource(Resource_Index).ToolRequired Then
                    PlayerMsg Index, "You have the wrong type of item equipped to use this resource!", BrightRed
                    Exit Sub
                End If
            End If
                
            ' Enough space in inventory?
            If Resource(Resource_Index).ItemReward > 0 Then
                If FindOpenInvSlot(Index, Resource(Resource_Index).ItemReward) = 0 Then
                    PlayerMsg Index, "You do not have enough inventory space!", BrightRed
                    Exit Sub
                End If
            End If

            ' Check if the resource has already been deplenished
            If ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).ResourceState = 0 Then
                rX = ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).X
                rY = ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).Y
            
                ' Reduce weapon's durability
                Call DamagePlayerEquipment(Index, Equipment.Weapon)
                
                ' Give the reward random when they deal damage
                RndNum = Random(Resource(Resource_Index).LowChance, Resource(Resource_Index).HighChance)
                  
                If Not RndNum = Resource(Resource_Index).LowChance Then
                    ' Subtract the RndNum by the random value of the weapon's chance modifier
                    RndNum = RndNum - Round(Random((Item(GetPlayerEquipment(Index, Weapon)).ChanceModifier / 2), Item(GetPlayerEquipment(Index, Weapon)).ChanceModifier))
                    
                    ' If value is less than the resource low chance then set it to it
                    If RndNum < Resource(Resource_Index).LowChance Then
                        RndNum = Resource(Resource_Index).LowChance
                    End If
                End If
                
                If RndNum = Resource(Resource_Index).LowChance Then
                    ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).Cur_Reward = ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).Cur_Reward - 1
                    GiveInvItem Index, Resource(Resource_Index).ItemReward, 1
                    
                    If GetPlayerSkill(Index, Resource(Resource_Index).Skill) < Options.MaxLevel Then
                        ' Add the experience to the skill
                        Call SetPlayerSkillExp(Index, GetPlayerSkillExp(Index, Resource(Resource_Index).Skill) + Resource(Resource_Index).Exp * EXP_RATE, Resource(Resource_Index).Skill)
                        
                        ' Check for skill level up
                        Call CheckPlayerSkillLevelUp(Index, Resource(Resource_Index).Skill)
                    End If
                    
                    ' Send message if it exists
                    If Len(Trim$(Resource(Resource_Index).SuccessMessage)) > 0 Then
                        SendActionMsg GetPlayerMap(Index), Trim$(Resource(Resource_Index).SuccessMessage), BrightGreen, 1, (GetPlayerX(Index) * 32), (GetPlayerY(Index) * 32)
                    End If
                    
                    ' If the resource is empty then clear it
                    If ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).Cur_Reward = 0 Then
                        ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).ResourceState = 1
                        ResourceCache(GetPlayerMap(Index)).ResourceData(Resource_Num).ResourceTimer = timeGetTime
                        SendResourceCacheToMap GetPlayerMap(Index), Resource_Num
                    End If
                Else
                    ' Send message if it exists
                    If Len(Trim$(Resource(Resource_Index).FailMessage)) > 0 Then
                        SendActionMsg GetPlayerMap(Index), Trim$(Resource(Resource_Index).FailMessage), BrightRed, 1, (GetPlayerX(Index) * 32), (GetPlayerY(Index) * 32)
                    End If
                End If
                
                SendAnimation GetPlayerMap(Index), Resource(Resource_Index).Animation, rX, rY
                
                ' Send the sound
                SendMapSound GetPlayerMap(Index), Index, rX, rY, SoundEntity.seResource, Resource_Index
            Else
                ' Send message if it exists
                If Len(Trim$(Resource(Resource_Index).EmptyMessage)) > 0 Then
                    SendActionMsg GetPlayerMap(Index), Trim$(Resource(Resource_Index).EmptyMessage), BrightRed, 1, (GetPlayerX(Index) * 32), (GetPlayerY(Index) * 32)
                    Exit Sub
                End If
            End If
        End If
    End If
End Sub

Sub GiveBankItem(ByVal Index As Long, ByVal InvSlot As Byte, ByVal Amount As Long, Optional ByVal Durability As Integer = 0)
    Dim BankSlot As Long
    
    BankSlot = FindOpenBankSlot(Index, GetPlayerInvItemNum(Index, InvSlot))
        
    If BankSlot > 0 And BankSlot <= MAX_BANK Then
        If Item(GetPlayerInvItemNum(Index, InvSlot)).stackable = 1 Then
            If GetPlayerBankItemNum(Index, BankSlot) = GetPlayerInvItemNum(Index, InvSlot) Then
                Call SetPlayerBankItemValue(Index, BankSlot, GetPlayerBankItemValue(Index, BankSlot) + Amount)
                Call TakeInvItem(Index, GetPlayerInvItemNum(Index, InvSlot), Amount)
            Else
                Call SetPlayerBankItemNum(Index, BankSlot, GetPlayerInvItemNum(Index, InvSlot))
                Call SetPlayerBankItemValue(Index, BankSlot, Amount)
                Call SetPlayerBankItemBind(Index, BankSlot, GetPlayerInvItemBind(Index, InvSlot))
                Call TakeInvItem(Index, GetPlayerInvItemNum(Index, InvSlot), Amount)
            End If
        Else
            If GetPlayerBankItemNum(Index, BankSlot) = GetPlayerInvItemNum(Index, InvSlot) And Not Item(GetPlayerInvItemNum(Index, InvSlot)).Type = ITEM_TYPE_EQUIPMENT Then
                Call SetPlayerBankItemValue(Index, BankSlot, GetPlayerBankItemValue(Index, BankSlot) + 1)
                Call TakeInvItem(Index, GetPlayerInvItemNum(Index, InvSlot), 0)
            Else
                Call SetPlayerBankItemNum(Index, BankSlot, GetPlayerInvItemNum(Index, InvSlot))
                Call SetPlayerBankItemValue(Index, BankSlot, 1)
                Call SetPlayerBankItemBind(Index, BankSlot, GetPlayerInvItemBind(Index, InvSlot))
                Call SetPlayerBankItemDur(Index, BankSlot, Durability)
                Call TakeInvItem(Index, GetPlayerInvItemNum(Index, InvSlot), 0)
            End If
        End If
    End If
    
    SendBank Index
End Sub

Sub TakeBankItem(ByVal Index As Long, ByVal BankSlot As Byte, ByVal Amount As Long)
    Dim InvSlot As Long

    If BankSlot < 1 Or BankSlot > MAX_BANK Then Exit Sub
    If GetPlayerBankItemNum(Index, BankSlot) < 1 Or GetPlayerBankItemNum(Index, BankSlot) > MAX_ITEMS Then Exit Sub
    
    ' Hack prevention
    If Item(GetPlayerBankItemNum(Index, BankSlot)).stackable = 1 Then
        If GetPlayerBankItemValue(Index, BankSlot) < Amount Then Amount = GetPlayerBankItemValue(Index, BankSlot)
        If Amount < 1 Then Exit Sub
    Else
        If Not Amount = 1 Then Exit Sub
    End If
    
    InvSlot = FindOpenInvSlot(Index, GetPlayerBankItemNum(Index, BankSlot))
        
    If InvSlot > 0 And InvSlot <= MAX_ITEMS Then
        If Item(GetPlayerBankItemNum(Index, BankSlot)).stackable = 1 Then
            Call GiveInvItem(Index, GetPlayerBankItemNum(Index, BankSlot), Amount)
            Call SetPlayerBankItemValue(Index, BankSlot, GetPlayerBankItemValue(Index, BankSlot) - Amount)
            
            If GetPlayerBankItemValue(Index, BankSlot) <= 0 Then
                Call SetPlayerBankItemNum(Index, BankSlot, 0)
                Call SetPlayerBankItemValue(Index, BankSlot, 0)
                Call SetPlayerBankItemBind(Index, BankSlot, 0)
            End If
        Else
            If GetPlayerBankItemValue(Index, BankSlot) > 1 Then
                Call GiveInvItem(Index, GetPlayerBankItemNum(Index, BankSlot), 0)
                Call SetPlayerBankItemValue(Index, BankSlot, GetPlayerBankItemValue(Index, BankSlot) - 1)
            Else
                Call GiveInvItem(Index, GetPlayerBankItemNum(Index, BankSlot), 0, GetPlayerBankItemDur(Index, BankSlot), GetPlayerBankItemBind(Index, BankSlot))
                Call SetPlayerBankItemNum(Index, BankSlot, 0)
                Call SetPlayerBankItemValue(Index, BankSlot, 0)
                Call SetPlayerBankItemDur(Index, BankSlot, 0)
                Call SetPlayerBankItemBind(Index, BankSlot, 0)
            End If
        End If
    End If
    
    SendBank Index
End Sub

Function TakeBankSlot(ByVal Index As Long, ByVal ItemNum As Integer, ByVal ItemVal As Long) As Boolean
    Dim i As Long

    ' Check for subscript out of range
    If IsPlaying(Index) = False Or ItemNum <= 0 Or ItemNum > MAX_ITEMS Then Exit Function

    For i = 1 To MAX_BANK
        ' Check to see if the player has the item
        If GetPlayerBankItemNum(Index, i) = ItemNum Then
            If Item(ItemNum).stackable = 1 Then
                ' Is what we are trying to take away more then what they have?  If so just set it to zero
                If ItemVal >= GetPlayerBankItemValue(Index, i) Then
                    TakeBankSlot = True
                Else
                    Call SetPlayerBankItemValue(Index, i, GetPlayerBankItemValue(Index, i) - ItemVal)
                    Exit Function
                End If
            Else
                TakeBankSlot = True
            End If

            If TakeBankSlot Then
                Call SetPlayerBankItemNum(Index, i, 0)
                Call SetPlayerBankItemValue(Index, i, 0)
                Call SetPlayerBankItemDur(Index, i, 0)
                Call SetPlayerBankItemBind(Index, i, 0)
                Exit For
            End If
        End If
    Next
    
    SendBank Index
End Function

Public Sub UseItem(ByVal Index As Long, ByVal InvNum As Byte)
    Dim n As Long, i As Long, X As Long, Y As Long, TotalPoints As Integer, EquipSlot As Byte
    Dim Item1 As Long
    Dim Item2 As Long
    Dim Result As Long
    Dim Skill As Byte
    Dim SkillExp As Integer
    Dim SkillLevelReq As Byte
    Dim ToolReq As Long

    ' Check subscript out of range
    If InvNum < 1 Or InvNum > MAX_INV Then Exit Sub
    
    ' Check if they can use the item
    If Not CanPlayerUseItem(Index, GetPlayerInvItemNum(Index, InvNum)) Then Exit Sub
    
    n = Item(GetPlayerInvItemNum(Index, InvNum)).Data2

    ' Set the bind
    If Item(GetPlayerInvItemNum(Index, InvNum)).Type = ITEM_TYPE_EQUIPMENT Then
        If Item(GetPlayerInvItemNum(Index, InvNum)).BindType = BIND_ON_EQUIP Then
            Call SetPlayerInvItemBind(Index, InvNum, BIND_ON_PICKUP)
        End If
    End If
            
    ' Find out what kind of item it is
    Select Case Item(GetPlayerInvItemNum(Index, InvNum)).Type
        Case ITEM_TYPE_EQUIPMENT
            EquipSlot = Item(GetPlayerInvItemNum(Index, InvNum)).EquipSlot
            
            If EquipSlot >= 1 And EquipSlot <= Equipment_Count - 1 Then
                If GetPlayerInvItemDur(Index, InvNum) > 0 Or Item(GetPlayerInvItemNum(Index, InvNum)).Indestructable = 1 Then
                    Call PlayerUnequipItem(Index, EquipSlot, False, False, True)
                    
                    PlayerMsg Index, "You equip " & CheckGrammar(Trim$(Item(GetPlayerInvItemNum(Index, InvNum)).Name)) & ".", BrightGreen
                    SetPlayerEquipment Index, GetPlayerInvItemNum(Index, InvNum), EquipSlot
                    SetPlayerEquipmentDur Index, GetPlayerInvItemDur(Index, InvNum), EquipSlot
                    SetPlayerEquipmentBind Index, GetPlayerInvItemBind(Index, InvNum), EquipSlot
                    TakeInvSlot Index, InvNum, 0, True
                    
                    ' Send update
                    SendInventoryUpdate Index, InvNum
                    Call SendWornEquipment(Index)
                    Call SendMapEquipment(Index)
                    SendPlayerStats Index
                    
                    ' Send vitals
                    For i = 1 To Vitals.Vital_Count - 1
                        Call SendVital(Index, i)
                    Next
                    
                    ' Send vitals to party if in one
                    If tempplayer(Index).InParty > 0 Then SendPartyVitals tempplayer(Index).InParty, Index
                    
                     ' Send the sound
                    SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
                Else
                    If Item(GetPlayerInvItemNum(Index, InvNum)).Data1 = 0 Then
                        Call PlayerMsg(Index, "This item lacks durability, report it to a staff member!", 12)
                    Else
                        Call PlayerMsg(Index, "The item you are trying to equip is broken!", 12)
                    End If
                End If
            End If
        
        Case ITEM_TYPE_CONSUME
            If GetPlayerLevel(Index) = Options.MaxLevel And Item(GetPlayerInvItemNum(Index, InvNum)).AddEXP > 0 Then
                Call PlayerMsg(Index, "You can't use items which modify your experience when your at the max level!", BrightRed)
                Exit Sub
            End If
            
            ' Add HP
            If Item(GetPlayerInvItemNum(Index, InvNum)).AddHP > 0 Then
                If Not GetPlayerVital(Index, HP) = GetPlayerMaxVital(Index, HP) Then
                    If tempplayer(Index).VitalPotionTimer(HP) > timeGetTime Then
                        Call PlayerMsg(Index, "You must wait before you can use another potion that modifies your health!", BrightRed)
                        Exit Sub
                    Else
                        If Item(GetPlayerInvItemNum(Index, InvNum)).HoT = 1 Then
                            tempplayer(Index).VitalCycle(HP) = Item(GetPlayerInvItemNum(Index, InvNum)).Data1
                            tempplayer(Index).VitalPotion(HP) = GetPlayerInvItemNum(Index, InvNum)
                            tempplayer(Index).VitalPotionTimer(HP) = timeGetTime + (Item(GetPlayerInvItemNum(Index, InvNum)).Data1 * 1000)
                        Else
                            Account(Index).Chars(GetPlayerChar(Index)).Vital(Vitals.HP) = Account(Index).Chars(GetPlayerChar(Index)).Vital(Vitals.HP) + Item(GetPlayerInvItemNum(Index, InvNum)).AddHP
                            SendActionMsg GetPlayerMap(Index), "+" & Item(GetPlayerInvItemNum(Index, InvNum)).AddHP, BrightGreen, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
                            SendVital Index, HP
                            tempplayer(Index).VitalPotionTimer(HP) = timeGetTime + PotionWaitTimer
                        End If
                    End If
                Else
                    Call PlayerMsg(Index, "Using this item will have no effect!", BrightRed)
                    Exit Sub
                End If
            End If
            
            ' Add MP
            If Item(GetPlayerInvItemNum(Index, InvNum)).AddMP > 0 Then
                If Not GetPlayerVital(Index, MP) = GetPlayerMaxVital(Index, MP) Then
                    If tempplayer(Index).VitalPotionTimer(MP) > timeGetTime And Item(GetPlayerInvItemNum(Index, InvNum)).AddHP < 1 Then
                        Call PlayerMsg(Index, "You must wait before you can use another potion that modifies your mana!", BrightRed)
                        Exit Sub
                    Else
                        If Item(GetPlayerInvItemNum(Index, InvNum)).HoT = 1 Then
                            tempplayer(Index).VitalCycle(MP) = Item(GetPlayerInvItemNum(Index, InvNum)).Data1
                            tempplayer(Index).VitalPotion(MP) = GetPlayerInvItemNum(Index, InvNum)
                            tempplayer(Index).VitalPotionTimer(MP) = timeGetTime + (Item(GetPlayerInvItemNum(Index, InvNum)).Data1 * 1000)
                        Else
                            Account(Index).Chars(GetPlayerChar(Index)).Vital(Vitals.MP) = Account(Index).Chars(GetPlayerChar(Index)).Vital(Vitals.MP) + Item(GetPlayerInvItemNum(Index, InvNum)).AddMP
                            SendActionMsg GetPlayerMap(Index), "+" & Item(GetPlayerInvItemNum(Index, InvNum)).AddMP, BrightBlue, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
                            SendVital Index, MP
                            tempplayer(Index).VitalPotionTimer(MP) = timeGetTime + PotionWaitTimer
                        End If
                    End If
                Else
                    Call PlayerMsg(Index, "Using this item will have no effect!", BrightRed)
                    Exit Sub
                End If
            End If
            
            ' Add exp
            If Item(GetPlayerInvItemNum(Index, InvNum)).AddEXP > 0 Then
                SetPlayerExp Index, GetPlayerExp(Index) + Item(GetPlayerInvItemNum(Index, InvNum)).AddEXP
                SendPlayerExp Index
                CheckPlayerLevelUp Index
                SendActionMsg GetPlayerMap(Index), "+" & Item(GetPlayerInvItemNum(Index, InvNum)).AddEXP & " Exp", White, ACTIONMSG_SCROLL, GetPlayerX(Index) * 32, GetPlayerY(Index) * 32
            End If
            
            Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, InvNum)).Animation, GetPlayerX(Index), GetPlayerY(Index))
            
            ' Send the sound
            SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
            
            ' Is it reusable, if not take the item away
            If Item(GetPlayerInvItemNum(Index, InvNum)).IsReusable = False Then
                Call TakeInvSlot(Index, InvNum, 1)
            End If
        
        Case ITEM_TYPE_SPELL
            ' Get the spell number
            n = Item(GetPlayerInvItemNum(Index, InvNum)).Data1

            If n > 0 Then
                i = FindOpenSpellSlot(Index)

                ' Make sure they have an open spell slot
                If i > 0 Then
                    ' Make sure they don't already have the spell
                    If Not HasSpell(Index, n) Then
                        ' Make sure it's a valid name and their is an icon
                        If Not Trim$(Spell(n).Name) = vbNullString And Not Spell(n).Icon = 0 Then
                            ' Send the sound
                            SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
                            Call SetPlayerSpell(Index, i, n)
                            Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, InvNum)).Animation, GetPlayerX(Index), GetPlayerY(Index))
                            Call TakeInvSlot(Index, InvNum, 1)
                            Call PlayerMsg(Index, "You have learned a new spell!", BrightGreen)
                            Call SendPlayerSpell(Index, i)
                        Else
                            Call PlayerMsg(Index, "This spell either does not have a name or icon, report this to a staff member.", BrightRed)
                            Exit Sub
                        End If
                    Else
                        Call PlayerMsg(Index, "You have already learned this spell!", BrightRed)
                        Exit Sub
                    End If
                Else
                    Call PlayerMsg(Index, "You have learned all that you can learn!", BrightRed)
                    Exit Sub
                End If
            Else
                Call PlayerMsg(Index, "This item does not have a spell, please inform a staff member!", BrightRed)
                Exit Sub
            End If
        
        Case ITEM_TYPE_TELEPORT
            If Moral(Map(GetPlayerMap(Index)).Moral).CanPK = 1 Then
                Call PlayerMsg(Index, "You can't teleport while in a PvP area!", BrightRed)
                Exit Sub
            End If
            
            Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, InvNum)).Animation, GetPlayerX(Index), GetPlayerY(Index))
            Call PlayerWarp(Index, Item(GetPlayerInvItemNum(Index, InvNum)).Data1, Item(GetPlayerInvItemNum(Index, InvNum)).Data2, Item(GetPlayerInvItemNum(Index, InvNum)).Data3)
            
            ' Send the sound
            SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
            
            ' Is it reusable, if not take item away
            If Item(GetPlayerInvItemNum(Index, InvNum)).IsReusable = False Then
                Call TakeInvSlot(Index, InvNum, 1)
            End If
            
        Case ITEM_TYPE_RESETSTATS
            TotalPoints = GetPlayerPoints(Index)
            
            For i = 1 To Stats.Stat_count - 1
                TotalPoints = TotalPoints + (GetPlayerRawStat(Index, i) - Class(GetPlayerClass(Index)).Stat(i))
                Call SetPlayerStat(Index, i, Class(GetPlayerClass(Index)).Stat(i))
            Next
            
            ' Send the sound
            SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
            
            Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, InvNum)).Animation, GetPlayerX(Index), GetPlayerY(Index))
            Call SetPlayerPoints(Index, TotalPoints)
            Call SendPlayerStats(Index)
            Call SendPlayerPoints(Index)
            Call PlayerMsg(Index, "Your stats have been reset!", Yellow)
            Call TakeInvSlot(Index, InvNum, 1)

        Case ITEM_TYPE_SPRITE
            Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, InvNum)).Animation, GetPlayerX(Index), GetPlayerY(Index))
            Call SetPlayerSprite(Index, Item(GetPlayerInvItemNum(Index, InvNum)).Data1)
            Call SendPlayerSprite(Index)
            
            ' Send the sound
            SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
        
            ' Is it reusable, if not take item away
            If Item(GetPlayerInvItemNum(Index, InvNum)).IsReusable = False Then
                Call TakeInvSlot(Index, InvNum, 1)
            End If
            
        Case ITEM_TYPE_TITLE
            Call SendAnimation(GetPlayerMap(Index), Item(GetPlayerInvItemNum(Index, InvNum)).Animation, GetPlayerX(Index), GetPlayerY(Index))
            Call AddPlayerTitle(Index, Item(GetPlayerInvItemNum(Index, InvNum)).Data1, InvNum)
            
            ' Send the sound
            SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerInvItemNum(Index, InvNum)
        
        Case ITEM_TYPE_RECIPE
            ' Get the recipe information
            Item1 = Item(GetPlayerInvItemNum(Index, InvNum)).Data1
            Item2 = Item(GetPlayerInvItemNum(Index, InvNum)).Data2
            Result = Item(GetPlayerInvItemNum(Index, InvNum)).Data3
            Skill = Item(GetPlayerInvItemNum(Index, InvNum)).Skill
            SkillExp = Item(GetPlayerInvItemNum(Index, InvNum)).SkillExp
            SkillLevelReq = Item(GetPlayerInvItemNum(Index, InvNum)).SkillLevelReq
            ToolReq = Item(GetPlayerInvItemNum(Index, InvNum)).ToolRequired
            
            ' Perform Recipe checks
            If Item1 <= 0 Or Item2 <= 0 Or Result <= 0 Or Skill <= 0 Then
                Call PlayerMsg(Index, "This is an incomplete recipe...", BrightRed)
                Exit Sub
            End If
            
            If GetPlayerEquipment(Index, Weapon) <> ToolReq And HasItem(Index, ToolReq) = 0 And ToolReq <> 0 Then
                Call PlayerMsg(Index, "You don't have the proper tool required to craft this item!", BrightRed)
                Exit Sub
            End If
            
            If GetPlayerSkill(Index, Skill) < SkillLevelReq Then
                Call PlayerMsg(Index, "Your " & GetSkillName(Skill) & " skill isn't high enough to craft this item (" & SkillLevelReq & ")!", BrightRed)
                Exit Sub
            End If
            
            ' Give the resulting item
            If HasItem(Index, Item1) Then
                If HasItem(Index, Item2) Then
                    Call TakeInvSlot(Index, Item1, 1)
                    Call TakeInvSlot(Index, Item2, 1)
                    Call GiveInvItem(Index, Result, 1)
                    Call PlayerMsg(Index, "You have successfully created " & Trim$(Item(Result).Name) & " and earned " & SkillExp & " experience for the skill " & GetSkillName(Skill) & ".", BrightGreen)
                    
                    If GetPlayerSkill(Index, Skill) < Options.MaxLevel Then
                        ' Add the experience to the skill
                        Call SetPlayerSkillExp(Index, GetPlayerSkillExp(Index, Skill) + SkillExp, Skill)
                        
                        ' Check for skill level up
                        Call CheckPlayerSkillLevelUp(Index, Skill)
                    End If
                    
                    Call SendPlayerData(Index)
                Else
                    Call PlayerMsg(Index, "You do not have all of the ingredients.", BrightRed)
                    Exit Sub
                End If
            Else
                Call PlayerMsg(Index, "You do not have all of the ingredients.", BrightRed)
                Exit Sub
            End If
    End Select
End Sub

Public Sub SetCheckpoint(ByVal Index As Long, ByVal MapNum As Integer, ByVal X As Long, ByVal Y As Long)
    ' Check if their checkpoint is already set here
    If Account(Index).Chars(GetPlayerChar(Index)).CheckPointMap = MapNum And Account(Index).Chars(GetPlayerChar(Index)).CheckPointX = X And Account(Index).Chars(GetPlayerChar(Index)).CheckPointY = Y Then
        Call PlayerMsg(Index, "Your checkpoint is already saved here!", BrightRed)
        Exit Sub
    End If
   
    PlayerMsg Index, "Your checkpoint has been saved.", BrightGreen
    
    ' Save the Checkpoint
    Account(Index).Chars(GetPlayerChar(Index)).CheckPointMap = MapNum
    Account(Index).Chars(GetPlayerChar(Index)).CheckPointX = X
    Account(Index).Chars(GetPlayerChar(Index)).CheckPointY = Y
End Sub

Public Sub UpdatePlayerEquipmentItems(ByVal Index As Long)
    Dim i As Long
    
    If GetPlayerEquipment(Index, Shield) > 0 And GetPlayerEquipment(Index, Weapon) > 0 Then
        If Item(GetPlayerEquipment(Index, Weapon)).TwoHanded = 1 Then
            Call PlayerUnequipItem(Index, Weapon, True, True, True)
        End If
    End If
    
    For i = 1 To Equipment_Count - 1
        If GetPlayerEquipment(Index, i) > 0 Then
            If Item(GetPlayerEquipment(Index, i)).EquipSlot <> i Then
                Call PlayerUnequipItem(Index, i, True, True, True)
            End If
        End If
    Next
End Sub

Public Sub UpdateAllPlayerEquipmentItems()
    Dim n As Long, i As Long
    
    For n = 1 To Player_HighIndex
        If IsPlaying(n) Then
            If GetPlayerEquipment(n, Shield) > 0 And GetPlayerEquipment(n, Weapon) > 0 Then
                If Item(GetPlayerEquipment(n, Weapon)).TwoHanded = 1 Then
                    Call PlayerUnequipItem(n, Weapon, True, True, True)
                End If
            End If
            
            For i = 1 To Equipment_Count - 1
                If GetPlayerEquipment(n, i) > 0 Then
                    If Item(GetPlayerEquipment(n, i)).EquipSlot <> i Then
                        Call PlayerUnequipItem(n, i, True, True, True)
                    End If
                End If
            Next
        End If
    Next
End Sub

Public Sub UpdatePlayerItems(ByVal Index As Long)
    Dim TmpItem As Long, TmpAmount As Long
    Dim i As Byte, InvAmount As Long, BankAmount As Long, X As Long

    ' Make sure the inventory items are not cached as a currency
    For i = 1 To MAX_INV
        TmpItem = GetPlayerInvItemNum(Index, i)
        InvAmount = CheckInventorySlots(Index, TmpItem)
        
        If TmpItem > 0 And TmpItem <= MAX_ITEMS Then
            If GetPlayerInvItemValue(Index, i) > 1 And Item(TmpItem).stackable = 0 Then
                TmpAmount = GetPlayerInvItemValue(Index, i)
                Call TakeInvSlot(Index, i, GetPlayerInvItemValue(Index, i))
                
                For X = 1 To TmpAmount
                    Call GiveInvItem(Index, TmpItem, 1)
                Next
            End If
            
            If GetPlayerInvItemValue(Index, i) = 0 And Item(TmpItem).Type <> ITEM_TYPE_EQUIPMENT Then
                Call TakeInvSlot(Index, i, 0)
                Call GiveInvItem(Index, TmpItem, 1)
            ElseIf InvAmount > 1 And Item(TmpItem).stackable = 1 And GetPlayerInvItemValue(Index, i) <= 1 Then
                Call TakeInvSlot(Index, i, 1)
                Call GiveInvItem(Index, TmpItem, 1)
            End If
        End If
    Next
    
    ' Make sure the Bank items are not cached as a currency
   ' For i = 1 To MAX_BANK
   '     TmpItem = GetPlayerBankItemNum(index, i)
   '     BankAmount = CheckBankSlots(index, TmpItem)
        
   '     If TmpItem > 0 And TmpItem <= MAX_ITEMS Then
   '         If GetPlayerBankItemValue(index, i) > 1 And Item(TmpItem).Stackable = 0 Then
   '             TmpAmount = GetPlayerBankItemValue(index, i)
   '             Call TakeBankSlot(index, i, GetPlayerBankItemValue(index, i))
                
   '             For X = 1 To TmpAmount
   '                 Call GiveBankItem(index, TmpItem, 1)
   '             Next
   '         End If
            
   '         If GetPlayerBankItemValue(index, i) = 0 And Item(TmpItem).Type <> ITEM_TYPE_EQUIPMENT Then
   '             Call TakeBankSlot(index, i, 0)
   '             Call GiveBankItem(index, TmpItem, 1)
   '         ElseIf BankAmount > 1 And Item(TmpItem).Stackable = 1 And GetPlayerBankItemValue(index, i) <= 1 Then
   '             Call TakeBankSlot(index, i, 1)
   '             Call GiveBankItem(index, TmpItem, 1)
   '         End If
   '     End If
   ' Next
End Sub

Public Sub UpdateAllPlayerItems(ByVal ItemNum As Integer)
    Dim TmpItem As Long
    Dim n As Long, i As Byte, X As Byte

    For n = 1 To Player_HighIndex
        If IsPlaying(n) Then
            UpdatePlayerItems n
        End If
    Next
End Sub

Public Sub UpdateClassData(ByVal Index As Long)
     Dim i As Long
    Dim TotalPoints As Long
    Dim TotalPoints2 As Long
    
    If GetPlayerAccess(Index) > STAFF_MODERATOR Then Exit Sub
    
    For i = 1 To Stats.Stat_count - 1
        TotalPoints = TotalPoints + Class(GetPlayerClass(Index)).Stat(i)
        TotalPoints2 = TotalPoints2 + GetPlayerRawStat(Index, i)
    Next

    TotalPoints = TotalPoints + ((GetPlayerLevel(Index) - 1) * Options.StatsLevel)
    TotalPoints2 = TotalPoints2 + GetPlayerPoints(Index)

    ' Verify incorrect class data
    If TotalPoints <> TotalPoints2 Then

        For i = 1 To Stats.Stat_count - 1
            Call SetPlayerStat(Index, i, Class(GetPlayerClass(Index)).Stat(i))
        Next

        Call SetPlayerPoints(Index, (GetPlayerLevel(Index) - 1) * Options.StatsLevel)
    End If

   If GetPlayerSprite(Index) = 0 Then
        If GetPlayerGender(Index) = GENDER_MALE Then
            Call SetPlayerSprite(Index, Class(GetPlayerClass(Index)).MaleSprite)
        Else
            Call SetPlayerSprite(Index, Class(GetPlayerClass(Index)).FemaleSprite)
        End If
        
        ' Sprite still nothing?
        If GetPlayerSprite(Index) = 0 Then
            Call SetPlayerSprite(Index, 1)
        End If
    End If
    
    If GetPlayerFace(Index) = 0 Then
        If GetPlayerGender(Index) = GENDER_MALE Then
            Call SetPlayerFace(Index, Class(GetPlayerClass(Index)).MaleFace)
        Else
            Call SetPlayerFace(Index, Class(GetPlayerClass(Index)).FemaleFace)
        End If
        
        ' Face still nothing?
        If GetPlayerFace(Index) = 0 Then
            Call SetPlayerFace(Index, 1)
        End If
    End If
End Sub

Public Sub UpdateAllClassData()
    Dim i As Long, X As Long
    
    For X = 1 To Player_HighIndex
        If GetPlayerAccess(X) <= STAFF_MODERATOR Then
            ' Verify incorrect class data
            For i = 1 To Stats.Stat_count - 1
                If Not Class(GetPlayerClass(X)).Stat(i) = GetPlayerStat(X, i) - ((GetPlayerLevel(X) - 1) * 5) Then
                    Call SetPlayerStat(X, i, Class(GetPlayerClass(X)).Stat(i) + ((GetPlayerLevel(X) - 1) * 5))
                End If
            Next
        
            If GetPlayerSprite(X) = 0 Then
                If GetPlayerGender(X) = GENDER_MALE Then
                    Call SetPlayerSprite(X, Class(GetPlayerClass(X)).MaleSprite)
                Else
                    Call SetPlayerSprite(X, Class(GetPlayerClass(X)).FemaleSprite)
                End If
                
                ' Sprite still nothing?
                If GetPlayerSprite(X) = 0 Then
                    Call SetPlayerSprite(X, 1)
                End If
            End If
            
            If GetPlayerFace(X) = 0 Then
                If GetPlayerGender(X) = GENDER_MALE Then
                    Call SetPlayerFace(X, Class(GetPlayerClass(X)).MaleFace)
                Else
                    Call SetPlayerFace(X, Class(GetPlayerClass(X)).FemaleFace)
                End If
                
                ' Face still nothing?
                If GetPlayerFace(X) = 0 Then
                    Call SetPlayerFace(X, 1)
                End If
            End If
        End If
    Next
End Sub

Function CanPlayerTrade(ByVal Index As Long, ByVal TradeTarget As Long) As Boolean
    Dim sX As Long, sY As Long, tX As Long, tY As Long
    
    ' Can't trade with yourself
    If TradeTarget = Index Then
        PlayerMsg Index, "You can't trade with yourself.", BrightRed
        Exit Function
    End If
    
    ' Make sure they're on the same map
    If Not Account(TradeTarget).Chars(GetPlayerChar(TradeTarget)).Map = Account(Index).Chars(GetPlayerChar(Index)).Map Then Exit Function
    
    ' Make sure they are allowed to trade
    If Account(TradeTarget).Chars(GetPlayerChar(Index)).CanTrade = False Then
        PlayerMsg Index, Trim$(GetPlayerName(TradeTarget)) & " has their trading turned off.", BrightRed
        Exit Function
    End If

    ' Make sure they're stood next to each other
    tX = Account(TradeTarget).Chars(GetPlayerChar(TradeTarget)).X
    tY = Account(TradeTarget).Chars(GetPlayerChar(TradeTarget)).Y
    sX = Account(Index).Chars(GetPlayerChar(Index)).X
    sY = Account(Index).Chars(GetPlayerChar(Index)).Y
    
    ' Within range?
    If tX < sX - 1 Or tX > sX + 1 And tY < sY - 1 Or tY > sY + 1 Then
        PlayerMsg Index, "You need to be standing next to someone to request or accept a trade.", BrightRed
        Exit Function
    End If
    
    CanPlayerTrade = True
End Function

Function CanPlayerUseItem(ByVal Index As Long, ByVal ItemNum As Integer, Optional Message As Boolean = True) As Boolean
    Dim LevelReq As Byte
    Dim AccessReq As Byte
    Dim ClassReq As Byte
    Dim GenderReq As Byte
    Dim i As Long

    ' Can't use items while in a map that doesn't allow it
    If Moral(Map(GetPlayerMap(Index)).Moral).CanUseItem = 0 Then
        Call PlayerMsg(Index, "You can't use items here!", BrightRed)
        Exit Function
    End If
    
    LevelReq = Item(ItemNum).LevelReq

    ' Make sure they are the right level
    If LevelReq > GetPlayerLevel(Index) Then
        If Message Then
            Call PlayerMsg(Index, "You must be level " & LevelReq & " to use this item.", BrightRed)
        End If
        Exit Function
    End If
    
    AccessReq = Item(ItemNum).AccessReq
    
    ' Make sure they have the right access
    If AccessReq > GetPlayerAccess(Index) Then
        If Message Then
            Call PlayerMsg(Index, "You must be a staff member to use this item.", BrightRed)
        End If
        Exit Function
    End If
    
    ClassReq = Item(ItemNum).ClassReq
    
    ' Make sure the Classes req > 0
    If ClassReq > 0 Then ' 0 = no req
        If Not ClassReq = GetPlayerClass(Index) Then
            If Message Then
                Call PlayerMsg(Index, "You must be " & CheckGrammar(Trim$(Class(ClassReq).Name)) & " can use this item!", BrightRed)
            End If
            Exit Function
        End If
    End If
    
    GenderReq = Item(ItemNum).GenderReq
    
    ' Make sure the Gender req > 0
    If GenderReq > 0 Then ' 0 = no req
        If Not GenderReq - 1 = GetPlayerGender(Index) Then
            If Message Then
                If GetPlayerGender(Index) = 0 Then
                    Call PlayerMsg(Index, "You need to be a female to use this item!", BrightRed)
                Else
                    Call PlayerMsg(Index, "You need to be a male to use this item!", BrightRed)
                End If
            End If
            Exit Function
        End If
    End If
    
    ' Check if they have the stats required to use this item
    For i = 1 To Stats.Stat_count - 1
        If GetPlayerRawStat(Index, i) < Item(ItemNum).Stat_Req(i) Then
            If Message Then
                PlayerMsg Index, "You do not meet the stat requirements to use this item.", BrightRed
            End If
            Exit Function
        End If
    Next
    
    ' Check if they have the proficiency required to use this item
    If Item(ItemNum).ProficiencyReq > 0 Then
        If GetPlayerProficiency(Index, Item(ItemNum).ProficiencyReq) = 0 Then
            If Message Then
                PlayerMsg Index, "You lack the proficiency to use this item!", BrightRed
            End If
            Exit Function
        End If
    End If
    
    ' Don't let them equip a two handed weapon if they have a shield on
     If Item(ItemNum).TwoHanded = 1 Then
        If GetPlayerEquipment(Index, Shield) > 0 Then
            PlayerMsg Index, "You must unequip your shield before equipping a two-handed weapon!", BrightRed
            Exit Function
        End If
    End If
    
    ' Don't let them use a tool they don't meet the level requirement to
    If Item(ItemNum).SkillReq > 0 Then
        If GetPlayerSkill(Index, Item(ItemNum).SkillReq) < Item(ItemNum).LevelReq Then
            PlayerMsg Index, "Your " & CheckGrammar(GetSkillName(Item(ItemNum).SkillReq)) & " skill level does not meet the requirement to use this item!", BrightRed
            Exit Function
        End If
    End If
    
    CanPlayerUseItem = True
End Function

Public Function CanPlayerCastSpell(ByVal Index As Long, ByVal SpellNum As Long) As Boolean
    ' Check if they have enough MP
    If GetPlayerVital(Index, Vitals.MP) < Spell(SpellNum).MPCost Then
        Call PlayerMsg(Index, "Not enough mana!", BrightRed)
        Exit Function
    End If
    
    ' Make sure they are the right level
    If Spell(SpellNum).LevelReq > GetPlayerLevel(Index) Then
        Call PlayerMsg(Index, "You must be level " & Spell(SpellNum).LevelReq & " to cast this spell.", BrightRed)
        Exit Function
    End If
    
    ' Make sure they have the right access
    If Spell(SpellNum).AccessReq > GetPlayerAccess(Index) Then
        Call PlayerMsg(Index, "You must be a staff member to cast this spell.", BrightRed)
        Exit Function
    End If
    
    ' Make sure the ClassReq > 0
    If Spell(SpellNum).ClassReq > 0 Then ' 0 = no req
        If Spell(SpellNum).ClassReq <> GetPlayerClass(Index) Then
            Call PlayerMsg(Index, "Only " & CheckGrammar(Trim$(Class(Spell(SpellNum).ClassReq).Name)) & " can use this spell.", BrightRed)
            Exit Function
        End If
    End If
    
    CanPlayerCastSpell = True
End Function

Public Sub DamagePlayerEquipment(ByVal Index As Long, ByVal EquipmentSlot As Byte)
    Dim ItemNum As Long, RandomNum As Byte
    
    ItemNum = GetPlayerEquipment(Index, EquipmentSlot)
    
    If ItemNum = 0 Then Exit Sub
    
    ' Make sure the item isn't indestructable
    If Item(ItemNum).Indestructable = 1 Then Exit Sub
    
    ' Don't subtract past 0
    If GetPlayerEquipmentDur(Index, EquipmentSlot) = 0 Then Exit Sub
    
    RandomNum = Random(1, 7)
    
    ' 1 in 7 chance it will actually damage the equipment if it's not a shield type item
    If RandomNum = 1 Or EquipmentSlot = Shield Then
        If Item(ItemNum).Type = ITEM_TYPE_EQUIPMENT Then
        
            ' Take away 1 durability
            Call SetPlayerEquipmentDur(Index, GetPlayerEquipmentDur(Index, EquipmentSlot) - 1, EquipmentSlot)
            Call SendWornEquipment(Index)
            Call SendMapEquipment(Index)
                
            If GetPlayerEquipmentDur(Index, EquipmentSlot) < 1 Then
                Call PlayerMsg(Index, "Your " & Trim$(Item(ItemNum).Name) & " has broken.", BrightRed)
                Call PlayerUnequipItem(Index, EquipmentSlot, True, True, True)
            ElseIf GetPlayerEquipmentDur(Index, EquipmentSlot) = 10 Then
                Call PlayerMsg(Index, "Your " & Trim$(Item(ItemNum).Name) & " is about to break!", BrightRed)
            End If
        End If
    End If
End Sub

Public Sub WarpToCheckPoint(Index As Long)
    Dim MapNum As Integer
    Dim X As Long, Y As Long
    
    MapNum = Account(Index).Chars(GetPlayerChar(Index)).CheckPointMap
    X = Account(Index).Chars(GetPlayerChar(Index)).CheckPointX
    Y = Account(Index).Chars(GetPlayerChar(Index)).CheckPointY
    
    PlayerWarp Index, MapNum, X, Y
End Sub

Function IsAFriend(ByVal Index As Long, ByVal OtherPlayer As Long) As Boolean
    Dim i As Long
    
    ' Are they on the user's friend list
    For i = 1 To Account(OtherPlayer).Friends.AmountOfFriends
        If Trim$(Account(OtherPlayer).Friends.Members(i)) = GetPlayerName(Index) Then
            IsAFriend = True
            Exit Function
        End If
    Next
End Function

Function IsAFoe(ByVal Index As Long, ByVal OtherPlayer As Long) As Boolean
    Dim i As Long
    
    ' Are they on the user's foe list
    For i = 1 To Account(OtherPlayer).Foes.Amount
        If Trim$(Account(OtherPlayer).Foes.Members(i)) = GetPlayerName(Index) Then
            Call PlayerMsg(Index, "You are being ignored by " & GetPlayerName(OtherPlayer) & "!", BrightRed)
            IsAFoe = True
            Exit Function
        End If
    Next
End Function

Function IsPlayerBusy(ByVal Index As Long, ByVal OtherPlayer As Long) As Boolean
    ' Make sure they're not busy doing something else
    If IsPlaying(OtherPlayer) Then
        If tempplayer(OtherPlayer).InBank Or tempplayer(OtherPlayer).InShop > 0 Or tempplayer(OtherPlayer).InTrade > 0 Or (tempplayer(OtherPlayer).PartyInvite > 0 And tempplayer(OtherPlayer).PartyInvite <> Index) Or (tempplayer(OtherPlayer).TradeRequest > 0 And tempplayer(OtherPlayer).TradeRequest <> Index) Or (tempplayer(OtherPlayer).GuildInvite > 0 And tempplayer(OtherPlayer).GuildInvite <> Index) Then
            IsPlayerBusy = True
            PlayerMsg Index, GetPlayerName(OtherPlayer) & " is busy!", BrightRed
            Exit Function
        End If
    End If
End Function

