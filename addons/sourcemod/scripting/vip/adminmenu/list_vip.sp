ShowVipPlayersListMenu(iClient)
{
	decl String:sUserID[12], String:sName[128], i, iClientID;
	Menu hMenu = new Menu(MenuHandler_VipPlayersListMenu);

	SetGlobalTransTarget(iClient);

	hMenu.SetTitle("%T:\n \n", "MENU_LIST_VIP", iClient);
	hMenu.ExitBackButton = true;
	
	
	/*	FormatEx(sBuffer, sizeof(sBuffer), "%t\n \n", "MENU_EDIT_VIP");
		hMenu.AddItem("", sBuffer);
		FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_DEL_VIP");
		hMenu.AddItem("", sBuffer);
	*/
	
	hMenu.AddItem("search", "Найти игрока\n \n");
	
	hMenu.AddItem("show_all", "Показать всех\n \n");
	
	sUserID[0] = 0;
	for (i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && (g_iClientInfo[i] & IS_VIP) && IsFakeClient(i) == false && GetClientName(i, sName, sizeof(sName)))
		{
			GetTrieValue(g_hFeatures[i], KEY_CID, iClientID);
			/*if(iClientID == -1)
			{
				FormatEx(sUserID, sizeof(sUserID), "uid_%i", UID(i));
			}
			else
			{
				IntToString(iClientID, sUserID, sizeof(sUserID));
			}
			
			hMenu.AddItem(sUserID, sName);*/
			
			IntToString(iClientID, sUserID, sizeof(sUserID));
			hMenu.AddItem(sUserID, sName, iClientID == -1 ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
		}
	}

	if(sUserID[0] == 0)
	{
		FormatEx(sName, sizeof(sName), "%T", "NO_PLAYERS_AVAILABLE", iClient);
		hMenu.AddItem("", sName, ITEMDRAW_DISABLED);
	}

	SetArrayCell(g_ClientData[iClient], DATA_OFFSET, -1);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public MenuHandler_VipPlayersListMenu(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
		case MenuAction_End: CloseHandle(hMenu);
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack) DisplayMenu(g_hVIPAdminMenu, iClient, MENU_TIME_FOREVER);
		}
		case MenuAction_Select:
		{
			decl String:sUserID[12];
			hMenu.GetItem(Item, sUserID, sizeof(sUserID));
			
			if(strcmp(sUserID, "more") == 0)	// Показать еще
			{
				ShowVipPlayersFromDBMenu(iClient, GetArrayCell(g_ClientData[iClient], DATA_OFFSET)+20);

				return;
			}
			
			if(strcmp(sUserID, "search") == 0)	// Найти игрока
			{
				ShowWaitSearchMenu(iClient);

				return;
			}
			
			if(strcmp(sUserID, "show_all") == 0)	// Показать всех
			{
				ShowVipPlayersFromDBMenu(iClient);

				return;
			}

			/*
			
			if(strncmp(sUserID, "uid_", 4) == 0)	// Временный VIP-статус
			{
				UserID = CID(StringToInt(sUserID[4]))
				if(UserID)
				{
					ShowTargetTempInfo(iClient, UserID);
				}
				else
				{
					VIP_PrintToChatClient(iClient, "%t", "PLAYER_NO_LONGER_AVAILABLE");
				}
				
				return;
				
			}
			*/

			new UserID = StringToInt(sUserID);
			SetArrayCell(g_ClientData[iClient], DATA_TARGET_ID, UserID);

			ShowTargetInfoMenu(iClient, UserID);
		}
	}
}

ShowWaitSearchMenu(iClient, const String:sSearch[] = "", bool:bIsValid = false)
{
	decl String:sBuffer[128];
	Menu hMenu = new Menu(MenuHandler_SearchPlayersListMenu);
	hMenu.SetTitle("%T \"%T\"\n \n", "ENTER_AUTH", iClient, "CONFIRM", iClient);


	FormatEx(sBuffer, sizeof(sBuffer), "%T", "CONFIRM", iClient);
	if(bIsValid)
	{
	//	g_iClientInfo[iClient] &= ~IS_WAIT_CHAT_SEARCH;
		hMenu.AddItem(sSearch, sBuffer);
	}
	else
	{
		g_iClientInfo[iClient] |= IS_WAIT_CHAT_SEARCH;
		hMenu.AddItem(sSearch, sBuffer, ITEMDRAW_DISABLED);
	}

	FormatEx(sBuffer, sizeof(sBuffer), "%T", "CANCEL", iClient);
	hMenu.AddItem("", sBuffer);
	
	ReductionMenu(hMenu, 4);
	
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public MenuHandler_SearchPlayersListMenu(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
		case MenuAction_End: CloseHandle(hMenu);
		case MenuAction_Cancel:
		{
			if(Item != MenuCancel_Interrupted)
			{
				g_iClientInfo[iClient] &= ~IS_WAIT_CHAT_SEARCH;
			}

			if(Item == MenuCancel_ExitBack)
			{
				ShowVipPlayersListMenu(iClient);
			}
		}
		case MenuAction_Select:
		{
			g_iClientInfo[iClient] &= ~IS_WAIT_CHAT_SEARCH;
			switch(Item)
			{
				case 0:
				{
					decl String:sQuery[512], String:sAuth[32];
					hMenu.GetItem(Item, sAuth, sizeof(sAuth));
					if (GLOBAL_INFO & IS_MySQL)
					{
						FormatEx(sQuery, sizeof(sQuery), "SELECT `u`.`id`, \
																`u`.`name` \
																FROM `vip_users` AS `u` \
																LEFT JOIN `vip_overrides` AS `o` \
																ON `o`.`user_id` = `u`.`id` \
																WHERE `o`.`server_id` = '%i' \
																AND (`u`.`auth` LIKE '%%%s%%' OR `u`.`name` LIKE '%%%s%%');",
																g_CVAR_iServerID, sAuth, sAuth);
					}
					else
					{
						FormatEx(sQuery, sizeof(sQuery), "SELECT `id`, `name` \
															FROM `vip_users` \
															WHERE (`auth` LIKE '%%%s%%' OR `name` LIKE '%%%s%%');",
															sAuth, sAuth);
					}

					DebugMessage(sQuery)
					g_hDatabase.Query(SQL_Callback_SelectVipPlayers, sQuery, UID(iClient));
					
				}
				case 1:
				{
					ShowVipPlayersListMenu(iClient);
				}
			}
		}
	}
}
/*
public SQL_Callback_SearchPlayers(Handle:hOwner, Handle:hQuery, const String:sError[], any:UserID)
{
	if (hQuery == null || sError[0])
	{
		LogError("SQL_Callback_SearchPlayers: %s", sError);
		return;
	}
	
	new iClient = CID(UserID);
	if (iClient)
	{
		decl String:sUserID[12], String:sName[128];
		Menu hMenu = new Menu(MenuHandler_VipPlayersListMenu);

		SetGlobalTransTarget(iClient);

		hMenu.SetTitle("%T:\n \n", "MENU_LIST_VIP", iClient);
		
		sUserID[0] = 0;
		
		while(SQL_FetchRow(hQuery))
		{
			IntToString(SQL_FetchInt(hQuery, 0), sUserID, sizeof(sUserID));
			SQL_FetchString(hQuery, 1, sName, sizeof(sName));
			
			hMenu.AddItem(sUserID, sName);
		}
	
		if(sUserID[0] == 0)
		{
			FormatEx(sName, sizeof(sName), "%T", "NO_PLAYERS_AVAILABLE", iClient);
			hMenu.AddItem("", sName, ITEMDRAW_DISABLED);
		}

		hMenu.Display(iClient, MENU_TIME_FOREVER);

	}
}
*/
ShowVipPlayersFromDBMenu(iClient, iOffset = 0)
{
	// , iRowCount = 20
	SetArrayCell(g_ClientData[iClient], DATA_OFFSET, iOffset);

	decl String:sQuery[512];
	if (GLOBAL_INFO & IS_MySQL)
	{
		FormatEx(sQuery, sizeof(sQuery), "SELECT `u`.`id`, \
												`u`.`name` \
												FROM `vip_users` AS `u` \
												LEFT JOIN `vip_overrides` AS `o` \
												ON `o`.`user_id` = `u`.`id` \
												WHERE `o`.`server_id` = '%i' LIMIT %i, 20;",
												g_CVAR_iServerID, iOffset);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery), "SELECT `id`, `name` \
											FROM `vip_users` LIMIT %i, 20;",
											iOffset);
	}

	DebugMessage(sQuery)
	g_hDatabase.Query(SQL_Callback_SelectVipPlayers, sQuery, UID(iClient));
}

public SQL_Callback_SelectVipPlayers(Handle:hOwner, Handle:hQuery, const String:sError[], any:UserID)
{
	if (hQuery == null || sError[0])
	{
		LogError("SQL_Callback_SelectVipPlayers: %s", sError);
		return;
	}
	
	new iClient = CID(UserID);
	if (iClient)
	{
		decl String:sUserID[12], String:sName[128];
		Menu hMenu = new Menu(MenuHandler_VipPlayersListMenu);
		hMenu.ExitBackButton = true;

		SetGlobalTransTarget(iClient);

		hMenu.SetTitle("%T:\n \n", "MENU_LIST_VIP", iClient);
		
		sUserID[0] = 0;
		
		while(SQL_FetchRow(hQuery))
		{
			IntToString(SQL_FetchInt(hQuery, 0), sUserID, sizeof(sUserID));
			SQL_FetchString(hQuery, 1, sName, sizeof(sName));
			
			hMenu.AddItem(sUserID, sName);
		}

		if(sUserID[0] == 0)
		{
			FormatEx(sName, sizeof(sName), "%T", "NO_PLAYERS_AVAILABLE", iClient);
			hMenu.AddItem("", sName, ITEMDRAW_DISABLED);
		}
		else if(GetArrayCell(g_ClientData[iClient], DATA_OFFSET) != -1)
		{
			hMenu.AddItem("", "ITEMDRAW_SPACER", ITEMDRAW_SPACER);
			hMenu.AddItem("more", "Показать еще");
		}

		hMenu.Display(iClient, MENU_TIME_FOREVER);

	}
}

ShowTargetInfoMenu(iClient, iClientID)
{
	decl String:sQuery[512];
	if (GLOBAL_INFO & IS_MySQL)
	{
		FormatEx(sQuery, sizeof(sQuery), "SELECT `o`.`group`, \
												`o`.`expires`, \
												`u`.`name`, \
												`u`.`auth` \
												FROM `vip_users` AS `u` \
												LEFT JOIN `vip_overrides` AS `o` \
												ON `o`.`user_id` = `u`.`id` \
												WHERE `o`.`server_id` = '%i' \
												AND `u`.`id` = '%i' LIMIT 1;",
												g_CVAR_iServerID, iClientID);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery), "SELECT `group`, \
												`expires`, \
												`name`, \
												`auth` \
												FROM `vip_users` \
												WHERE `id` = '%i' LIMIT 1;",
												iClientID);
	}

	DebugMessage(sQuery)
	g_hDatabase.Query(SQL_Callback_SelectVipClientInfo, sQuery, UID(iClient));
}


public SQL_Callback_SelectVipClientInfo(Handle:hOwner, Handle:hQuery, const String:sError[], any:UserID)
{
	if (hQuery == null || sError[0])
	{
		LogError("SQL_Callback_SelectVipClientInfo: %s", sError);
		return;
	}
	
	new iClient = CID(UserID);
	if (iClient)
	{
		if (SQL_FetchRow(hQuery))
		{
			SetGlobalTransTarget(iClient);

			decl String:sGroup[64], String:sBuffer[64], String:sName[64], String:sAuth[64], iExpires;
			Menu hMenu = new Menu(MenuHandler_VipClientInfoMenu);

			hMenu.ExitBackButton = true;

			if(SQL_IsFieldNull(hQuery, 1) == false)
			{
				SQL_FetchString(hQuery, 1, sGroup, sizeof(sGroup));	// GROUP
				if(sGroup[0])
				{
					SetArrayString(g_ClientData[iClient], DATA_GROUP, sGroup);
				}
				else
				{
				//	strcopy(sGroup, sizeof(sGroup), "none");
					SetArrayString(g_ClientData[iClient], DATA_GROUP, "none");
					FormatEx(sGroup, sizeof(sGroup), "%t", "NONE");
				}
			}
			else
			{
			//	strcopy(sGroup, sizeof(sGroup), "none");
				SetArrayString(g_ClientData[iClient], DATA_GROUP, "none");
				FormatEx(sGroup, sizeof(sGroup), "%t", "NONE");
			}

			iExpires = SQL_FetchInt(hQuery, 2);	// Expires
			SetArrayCell(g_ClientData[iClient], DATA_AUTH_TYPE, iExpires);

			if(iExpires > 0)
			{
				new iTime = GetTime();
				if(iExpires > iTime)
				{
					UTIL_GetTimeFromStamp(sBuffer, sizeof(sBuffer), iExpires-iTime, iClient);
					Format(sBuffer, sizeof(sBuffer), "%t: %s", "EXPIRE", sBuffer);
				}
				else
				{
					FormatEx(sBuffer, sizeof(sBuffer), "%t", "EXPIRED");
				}
			}
			else
			{
				FormatEx(sBuffer, sizeof(sBuffer), "%t", "NEVER");
			}

			SQL_FetchString(hQuery, 3, sName, sizeof(sName));	// Name
			SetArrayString(g_ClientData[iClient], DATA_NAME, sName);

			SQL_FetchString(hQuery, 4, sAuth, sizeof(sAuth));	// Auth

			hMenu.SetTitle("%t\n \n", "MENU_INFO_VIP_PLAYER", sName, sGroup, sBuffer, sAuth);

			FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_DEL_VIP");        	//		1. Удалить игрока
			hMenu.AddItem("", sBuffer);
			FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_EDIT_TIME");       //		2. Изменить срок 
			hMenu.AddItem("", sBuffer);
			FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_EDIT_GROUP");     //		4. Изменить группу
			hMenu.AddItem("", sBuffer);
			
			ReductionMenu(hMenu, 2);
			
			hMenu.Display(iClient, MENU_TIME_FOREVER);
		}
		else
		{
			VIP_PrintToChatClient(iClient, "%t", "FAILED_TO_LOAD_PLAYER");
		}
	}
}
/*
ShowTargetTempInfo(iClient, UserID)
{
	SetGlobalTransTarget(iClient);

	decl String:sGroup[64], String:sBuffer[64], String:sName[64], String:sAuthType[64], String:sAuth[64], iExpires;
	Menu hMenu = new Menu(MenuHandler_VipClientInfoMenu);

	hMenu.ExitBackButton = true;
	
	if(GetTrieString(g_hFeatures[iClient], KEY_GROUP, sGroup, sizeof(sGroup)) == false)	// GROUP
	{
		FormatEx(sGroup, sizeof(sGroup), "%t", "NONE");
	}

	GetTrieValue(g_hFeatures[iClient], KEY_EXPIRES, iExpires);
	if(iExpires > 0)
	{
		new iTime = GetTime();
		if(iExpires > iTime)
		{
			UTIL_GetTimeFromStamp(sBuffer, sizeof(sBuffer), iExpires-iTime, iClient);
			Format(sBuffer, sizeof(sBuffer), "%t: %s", "EXPIRE", sBuffer);
		}
		else
		{
			FormatEx(sBuffer, sizeof(sBuffer), "%t", "EXPIRED");
		}
	}
	else
	{
		FormatEx(sBuffer, sizeof(sBuffer), "%t", "NEVER");
	}


	hMenu.SetTitle("%t\n \n", "MENU_INFO_VIP_PLAYER", sName, sGroup, sBuffer, sAuthType, sAuth);

	FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_DEL_VIP");        	//		1. Удалить игрока
	hMenu.AddItem("", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_EDIT_TIME");       //		2. Изменить срок 
	hMenu.AddItem("", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_EDIT_PASS");       //		3. Изменить группу 
	hMenu.AddItem("", sBuffer);
	FormatEx(sBuffer, sizeof(sBuffer), "%t", "MENU_EDIT_GROUP");     //		4. Изменить пароль
	hMenu.AddItem("", sBuffer);
	
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}
*/
public MenuHandler_VipClientInfoMenu(Menu hMenu, MenuAction action, int iClient, int Item)
{
	switch(action)
	{
		case MenuAction_End: CloseHandle(hMenu);
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack)
			{
				new iOffset = GetArrayCell(g_ClientData[iClient], DATA_OFFSET);
				if(iOffset == -1)
				{
					ShowVipPlayersListMenu(iClient);
				}
				else
				{
					ShowVipPlayersFromDBMenu(iClient,iOffset);
				}
			}
		}
		case MenuAction_Select:
		{
			switch(Item)
			{
				case 0:	ShowDeleteVipPlayerMenu(iClient);
				case 1:	ShowEditTimeMenu(iClient);
				case 2: ShowEditGroupMenu(iClient);	
			}
		}
	}
}