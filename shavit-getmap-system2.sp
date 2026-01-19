#include <sourcemod>
#include <convar_class>
#include <system2>
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

Convar           gCV_PublicURL      = null;
Convar           gCV_MapsPath       = null;
Convar           gCV_FastDLPath     = null;
Convar           gCV_ReplaceMap     = null;
Convar           gCV_MapPrefix      = null;
Convar           gCV_DeleteBZ2After = null;
Convar           gCV_7ZipBinary     = null;
Convar           gCV_MapListURL     = null;

ArrayList        g_aMapList         = null;
bool             g_bMapListLoaded   = false;

char             gS_PublicURL[PLATFORM_MAX_PATH];
char             gS_MapPath[PLATFORM_MAX_PATH];
char             gS_FastDLPath[PLATFORM_MAX_PATH];
char             gS_MapPrefix[16];

chatstrings_t    gS_ChatStrings;

public Plugin myinfo =
{
    name        = "Shavit GetMap (System2)",
    author      = "BoomShot / Nora",
    description = "Allows a user with !map privileges to download a map while in-game (System2 version).",
    version     = "1.3.1",
    url         = "https://github.com/akanora/GetMap"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_getmap", Command_GetMap, ADMFLAG_CHANGEMAP, "Download a bz2 compressed map file to use in the server");
    RegAdminCmd("sm_download", Command_GetMap, ADMFLAG_CHANGEMAP, "Download a bz2 compressed map file to use in the server");
    RegAdminCmd("sm_downloadmap", Command_GetMap, ADMFLAG_CHANGEMAP, "Download a bz2 compressed map file to use in the server");
    RegAdminCmd("sm_delmap", Command_DeleteMap, ADMFLAG_CHANGEMAP, "Delete a map (.bsp and optionally .bz2) from the server.");

    gCV_PublicURL      = new Convar("gm_public_url", "https://main.fastdl.me/maps/", "Replace with a public FastDL URL containing maps for your respective game, the default one is for (cstrike).");
    gCV_MapsPath       = new Convar("gm_maps_path", "maps/", "Path to where the decompressed map file will go to.");
    gCV_FastDLPath     = new Convar("gm_fastdl_path", "maps/", "Path to where the compressed map file will go to.");
    gCV_ReplaceMap     = new Convar("gm_replace_map", "0", "Specifies whether or not to replace the map if it already exists.", _, true, 0.0, true, 1.0);
    gCV_MapPrefix      = new Convar("gm_map_prefix", "", "Use map prefix before every map name.");
    gCV_DeleteBZ2After = new Convar("gm_delete_bz2_after", "1", "Whether to delete the .bz2 after decompressing it.", _, true, 0.0, true, 1.0);
    gCV_7ZipBinary     = new Convar("gm_7zip_binary", "7z", "Path to the 7-zip executable (default '7z'). Change if not in system path.");
    gCV_MapListURL     = new Convar("gm_map_list_url", "https://main.fastdl.me/maps_index.html.txt", "URL to the plain text file containing the list of available maps.");

    RegAdminCmd("sm_maplist", Command_MapList, ADMFLAG_CHANGEMAP, "List available maps from FastDL.");
    RegAdminCmd("sm_findmap", Command_FindMap, ADMFLAG_CHANGEMAP, "Search for a map from FastDL.");
    RegAdminCmd("sm_refreshmaplist", Command_RefreshMapList, ADMFLAG_CHANGEMAP, "Force refresh the map list.");

    g_aMapList = new ArrayList(PLATFORM_MAX_PATH);

    AutoExecConfig(true, "shavit-getmap-system2");

    DownloadMapList();
}

public void Shavit_OnChatConfigLoaded()
{
    Shavit_GetChatStringsStruct(gS_ChatStrings);
}

public Action Command_GetMap(int client, int args)
{
    if (args < 1)
    {
        Shavit_PrintToChat(client, "Usage: sm_getmap <mapname>");
        return Plugin_Handled;
    }

    char mapName[PLATFORM_MAX_PATH];
    GetCmdArg(1, mapName, sizeof(mapName));

    if (mapName[0] == '\0')
    {
        Shavit_PrintToChat(client, "Usage: sm_getmap <mapname>");
        return Plugin_Handled;
    }

    gCV_PublicURL.GetString(gS_PublicURL, sizeof(gS_PublicURL));
    gCV_MapsPath.GetString(gS_MapPath, sizeof(gS_MapPath));
    gCV_FastDLPath.GetString(gS_FastDLPath, sizeof(gS_FastDLPath));
    gCV_MapPrefix.GetString(gS_MapPrefix, sizeof(gS_MapPrefix));

    if (gS_PublicURL[0] == '\0')
    {
        Shavit_PrintToChat(client, "Invalid public URL path, please update cvar: gm_public_url");
        return Plugin_Handled;
    }
    else if (!FormatOutputPath(gS_MapPath, sizeof(gS_MapPath), gS_MapPrefix, mapName, ".bsp"))
    {
        Shavit_PrintToChat(client, "Invalid maps path, please update cvar: gm_maps_path");
        return Plugin_Handled;
    }
    else if (!FormatOutputPath(gS_FastDLPath, sizeof(gS_FastDLPath), gS_MapPrefix, mapName, ".bsp.bz2"))
    {
        Shavit_PrintToChat(client, "Invalid fastdl path, please update cvar: gm_fastdl_path");
        return Plugin_Handled;
    }
    else if ((FileExists(gS_MapPath) || FileExists(gS_FastDLPath)) && !gCV_ReplaceMap.BoolValue)
    {
        Shavit_PrintToChat(client, "Map already exists! Use gm_replace_map to allow overwriting.");
        return Plugin_Handled;
    }

    char endPoint[PLATFORM_MAX_PATH];
    char fullURL[2048];

    if (StrContains(mapName, gS_MapPrefix, false) == -1)
    {
        Format(endPoint, sizeof(endPoint), "%s%s.bsp.bz2", gS_MapPrefix, mapName);
    }
    else
    {
        Format(endPoint, sizeof(endPoint), "%s.bsp.bz2", mapName);
    }

    Format(fullURL, sizeof(fullURL), "%s%s", gS_PublicURL, endPoint);

    Shavit_PrintToChat(client, "%sDownloading %s%s%s...", gS_ChatStrings.sText, gS_ChatStrings.sVariable, mapName, gS_ChatStrings.sText);

    DataPack data = new DataPack();
    data.WriteCell(client);
    data.WriteString(mapName);

    System2HTTPRequest request = new System2HTTPRequest(OnMapFileDownloaded, fullURL);
    request.SetOutputFile(gS_FastDLPath);
    request.Any = data;
    request.GET();

    return Plugin_Handled;
}

void OnMapFileDownloaded(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    DataPack data = view_as<DataPack>(request.Any);
    data.Reset();
    int  client = data.ReadCell();
    char mapName[PLATFORM_MAX_PATH];
    data.ReadString(mapName, sizeof(mapName));

    char fastDLPath[PLATFORM_MAX_PATH];
    gCV_FastDLPath.GetString(fastDLPath, sizeof(fastDLPath));
    char mapPrefix[16];
    gCV_MapPrefix.GetString(mapPrefix, sizeof(mapPrefix));
    FormatOutputPath(fastDLPath, sizeof(fastDLPath), mapPrefix, mapName, ".bsp.bz2");

    if (!success || response.StatusCode != 200)
    {
        LogError("GetMap: Failed to download %s. Success: %d, Status: %d, Error: %s", mapName, success, (response != null) ? response.StatusCode : 0, error);

        int statusCode = (response != null) ? response.StatusCode : 0;
        Shavit_PrintToChat(client, "%sFailed to download %s%s%s: HTTPStatus (%s%d%s)", gS_ChatStrings.sText, gS_ChatStrings.sVariable, mapName, gS_ChatStrings.sText, gS_ChatStrings.sVariable, statusCode, gS_ChatStrings.sText);

        if (FileExists(fastDLPath))
        {
            DeleteFile(fastDLPath);
        }

        delete data;
        return;
    }

    Shavit_PrintToChat(client, "%sDownload complete. Decompressing map file...", gS_ChatStrings.sText);

    Shavit_PrintToChat(client, "%sDownload complete. Decompressing map file...", gS_ChatStrings.sText);

    char mapPath[PLATFORM_MAX_PATH];
    gCV_MapsPath.GetString(mapPath, sizeof(mapPath));

    char outDir[PLATFORM_MAX_PATH];
    strcopy(outDir, sizeof(outDir), mapPath);
    int len = strlen(outDir);
    if (len > 0 && (outDir[len - 1] == '/' || outDir[len - 1] == '\\'))
    {
        outDir[len - 1] = '\0';
    }

    if (!FileExists(fastDLPath))
    {
        Shavit_PrintToChat(client, "%sError: Compressed file not found locally: %s", gS_ChatStrings.sText, fastDLPath);
        LogError("GetMap: Compressed file not found locally: %s", fastDLPath);
        delete data;
        return;
    }

    char gameDir[PLATFORM_MAX_PATH];
    System2_GetGameDir(gameDir, sizeof(gameDir));

    char absFastDLPath[PLATFORM_MAX_PATH];
    char absOutDir[PLATFORM_MAX_PATH];

    if (fastDLPath[0] != '/' && fastDLPath[1] != ':')
    {
        Format(absFastDLPath, sizeof(absFastDLPath), "%s/%s", gameDir, fastDLPath);
    }
    else
    {
        strcopy(absFastDLPath, sizeof(absFastDLPath), fastDLPath);
    }

    if (outDir[0] != '/' && outDir[1] != ':')
    {
        Format(absOutDir, sizeof(absOutDir), "%s/%s", gameDir, outDir);
    }
    else
    {
        strcopy(absOutDir, sizeof(absOutDir), outDir);
    }

    char binary[64];
    gCV_7ZipBinary.GetString(binary, sizeof(binary));

    char command[2048];
    Format(command, sizeof(command), "%s x \"%s\" -o\"%s\" -y", binary, absFastDLPath, absOutDir);

    System2_ExecuteThreaded(OnDecompressFile, command, data);
}

void OnDecompressFile(bool success, const char[] command, System2ExecuteOutput output, any data)
{
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();
    int  client = pack.ReadCell();
    char mapName[PLATFORM_MAX_PATH];
    pack.ReadString(mapName, sizeof(mapName));
    delete pack;    // Done with data

    if (!success || (output != null && output.ExitStatus != 0))
    {
        char outputStr[2048];
        if (output != null) output.GetOutput(outputStr, sizeof(outputStr));

        LogError("GetMap: Failed to decompress map. Success: %d, ExitStatus: %d, Output: %s", success, (output != null) ? output.ExitStatus : -1, outputStr);
        Shavit_PrintToChat(client, "%sFailed to decompress %s%s%s. Check error logs.", gS_ChatStrings.sText, gS_ChatStrings.sVariable, mapName, gS_ChatStrings.sText);
        return;
    }

    char fastDLPath[PLATFORM_MAX_PATH];
    char mapPrefix[16];
    gCV_FastDLPath.GetString(fastDLPath, sizeof(fastDLPath));
    gCV_MapPrefix.GetString(mapPrefix, sizeof(mapPrefix));
    FormatOutputPath(fastDLPath, sizeof(fastDLPath), mapPrefix, mapName, ".bsp.bz2");

    if (gCV_DeleteBZ2After.BoolValue && FileExists(fastDLPath))
    {
        if (DeleteFile(fastDLPath))
        {
            Shavit_PrintToChat(client, "%sDeleted compressed file.", gS_ChatStrings.sText);
        }
        else
        {
            Shavit_PrintToChat(client, "%sFailed to delete compressed file.", gS_ChatStrings.sText);
        }
    }

    Shavit_PrintToChat(client, "%sMap successfully added to the server! Use !map %s%s%s to change to it.", gS_ChatStrings.sText, gS_ChatStrings.sVariable, mapName, gS_ChatStrings.sText);
}

public Action Command_DeleteMap(int client, int args)
{
    if (args < 1)
    {
        Shavit_PrintToChat(client, "Usage: sm_delmap <mapname>");
        return Plugin_Handled;
    }

    char mapName[PLATFORM_MAX_PATH];
    GetCmdArg(1, mapName, sizeof(mapName));

    if (mapName[0] == '\0')
    {
        Shavit_PrintToChat(client, "Invalid map name.");
        return Plugin_Handled;
    }

    char bspPath[PLATFORM_MAX_PATH];
    char bz2Path[PLATFORM_MAX_PATH];
    char navPath[PLATFORM_MAX_PATH];
    char prefix[16];

    gCV_MapsPath.GetString(bspPath, sizeof(bspPath));
    gCV_FastDLPath.GetString(bz2Path, sizeof(bz2Path));
    gCV_MapPrefix.GetString(prefix, sizeof(prefix));

    if (!FormatOutputPath(bspPath, sizeof(bspPath), prefix, mapName, ".bsp") || !FormatOutputPath(bz2Path, sizeof(bz2Path), prefix, mapName, ".bsp.bz2"))
    {
        Shavit_PrintToChat(client, "Invalid path.");
        return Plugin_Handled;
    }

    strcopy(navPath, sizeof(navPath), bspPath);
    ReplaceString(navPath, sizeof(navPath), ".bsp", ".nav", false);

    bool bspDeleted = FileExists(bspPath) && DeleteFile(bspPath);
    bool bz2Deleted = FileExists(bz2Path) && DeleteFile(bz2Path);
    bool navDeleted = FileExists(navPath) && DeleteFile(navPath);

    if (!bspDeleted && !bz2Deleted && !navDeleted)
    {
        Shavit_PrintToChat(client, "Map not found or could not be deleted.");
    }
    else
    {
        Shavit_PrintToChat(client, "Deleted:%s%s%s",
                           bspDeleted ? " .bsp" : "",
                           bz2Deleted ? " .bz2" : "",
                           navDeleted ? " .nav" : "");
    }

    return Plugin_Handled;
}

bool FormatOutputPath(char[] path, int maxlen, char[] prefix, const char[] mapName, const char[] extension)
{
    if (path[0] == '\0')
    {
        strcopy(path, maxlen, "./");
    }

    // Ensure trailing slash
    if (path[strlen(path) - 1] != '/')
    {
        StrCat(path, maxlen, "/");
    }

    char temp[PLATFORM_MAX_PATH];
    strcopy(temp, sizeof(temp), path);

    // Append prefix if needed
    if (prefix[0] != '\0' && prefix[strlen(prefix) - 1] != '_')
    {
        StrCat(prefix, 16, "_");
    }

    if (StrContains(mapName, prefix, false) == -1)
    {
        StrCat(path, maxlen, prefix);
    }

    StrCat(path, maxlen, mapName);
    StrCat(path, maxlen, extension);

    return DirExists(temp);
}

void DownloadMapList(int client = 0)
{
    char url[1024];
    gCV_MapListURL.GetString(url, sizeof(url));

    if (url[0] == '\0') return;

    if (client != 0)
    {
        Shavit_PrintToChat(client, "%sRefreshing map list...", gS_ChatStrings.sText);
    }

    System2HTTPRequest request = new System2HTTPRequest(OnMapListDownloaded, url);
    char               path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/shavit-getmap-list.txt");
    request.SetOutputFile(path);
    request.Any = client;
    request.GET();
}

public Action Command_RefreshMapList(int client, int args)
{
    DownloadMapList(client);
    return Plugin_Handled;
}

void OnMapListDownloaded(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    int client = request.Any;
    delete request;

    if (success && response.StatusCode == 200)
    {
        ParseMapList(client);
    }
    else
    {
        if (client != 0)
        {
            Shavit_PrintToChat(client, "%sFailed to download map list. Status: %d. Error: %s", gS_ChatStrings.sText, response.StatusCode, error);
        }
        LogError("GetMap: Failed to download map list. Status: %d. Error: %s", response.StatusCode, error);
    }
}

void ParseMapList(int client)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/shavit-getmap-list.txt");

    File file = OpenFile(path, "r");
    if (file == null)
    {
        if (client != 0) Shavit_PrintToChat(client, "%sError opening map list file.", gS_ChatStrings.sText);
        return;
    }

    g_aMapList.Clear();

    char line[PLATFORM_MAX_PATH];
    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
    {
        TrimString(line);
        if (line[0] != '\0')
        {
            g_aMapList.PushString(line);
        }
    }
    delete file;
    g_bMapListLoaded = true;

    if (client != 0)
    {
        Shavit_PrintToChat(client, "%sMap list refreshed. %d maps found.", gS_ChatStrings.sText, g_aMapList.Length);
    }
}

bool IsMapInstalled(const char[] mapName)
{
    char mapDir[PLATFORM_MAX_PATH];
    gCV_MapsPath.GetString(mapDir, sizeof(mapDir));

    char prefix[16];
    gCV_MapPrefix.GetString(prefix, sizeof(prefix));

    char fullPath[PLATFORM_MAX_PATH];
    strcopy(fullPath, sizeof(fullPath), mapDir);

    FormatOutputPath(fullPath, sizeof(fullPath), prefix, mapName, ".bsp");

    return FileExists(fullPath);
}

public Action Command_MapList(int client, int args)
{
    if (!g_bMapListLoaded)
    {
        Shavit_PrintToChat(client, "%sMap list is not loaded yet. Trying to download...", gS_ChatStrings.sText);
        DownloadMapList(client);
        return Plugin_Handled;
    }

    if (g_aMapList.Length == 0)
    {
        Shavit_PrintToChat(client, "%sMap list is empty.", gS_ChatStrings.sText);
        return Plugin_Handled;
    }

    Menu menu  = new Menu(MenuHandler_MapList);

    int  count = 0;
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        char mapName[PLATFORM_MAX_PATH];
        g_aMapList.GetString(i, mapName, sizeof(mapName));

        if (IsMapInstalled(mapName)) continue;

        menu.AddItem(mapName, mapName);
        count++;
    }

    if (count == 0)
    {
        Shavit_PrintToChat(client, "%sAll cached maps are already installed.", gS_ChatStrings.sText);
        delete menu;
    }
    else
    {
        menu.SetTitle("GetMap - Available Maps (%d)", count);
        menu.Display(client, MENU_TIME_FOREVER);
    }

    return Plugin_Handled;
}

public Action Command_FindMap(int client, int args)
{
    if (args < 1)
    {
        Shavit_PrintToChat(client, "%sUsage: sm_findmap <partial name>", gS_ChatStrings.sText);
        return Plugin_Handled;
    }

    if (!g_bMapListLoaded)
    {
        Shavit_PrintToChat(client, "%sMap list is not loaded yet. Trying to download...", gS_ChatStrings.sText);
        DownloadMapList(client);
        return Plugin_Handled;
    }

    char query[64];
    GetCmdArg(1, query, sizeof(query));

    Menu menu  = new Menu(MenuHandler_MapList);

    int  count = 0;
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        char mapName[PLATFORM_MAX_PATH];
        g_aMapList.GetString(i, mapName, sizeof(mapName));

        if (StrContains(mapName, query, false) != -1)
        {
            if (IsMapInstalled(mapName)) continue;

            menu.AddItem(mapName, mapName);
            count++;
        }
    }

    if (count == 0)
    {
        Shavit_PrintToChat(client, "%sNo new maps found matching '%s'.", gS_ChatStrings.sText, query);
        delete menu;
    }
    else
    {
        menu.SetTitle("GetMap - Search Results: %s (%d)", query, count);
        menu.Display(client, MENU_TIME_FOREVER);
    }

    return Plugin_Handled;
}

public int MenuHandler_MapList(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char mapName[PLATFORM_MAX_PATH];
        menu.GetItem(param2, mapName, sizeof(mapName));

        // Trigger download
        FakeClientCommand(param1, "sm_getmap %s", mapName);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}
