# Shavit GetMap (System2)

Allows a user with `!map` privileges to download a map while in-game. This version utilizes the System2 extension for handling HTTP downloads and relies on 7-Zip for map decompression.

## Dependencies

This plugin requires the following dependencies to function correctly:

*   **[Shavit's Bhop Timer](https://github.com/shavitush/bhoptimer/releases)**
*   **[System2 Extension](https://github.com/dordnung/System2/releases)**

## Installation

1.  Ensure you have **SourceMod** and **MetaMod** installed.
2.  Install the **Shavit's Bhop Timer** core plugin.
3.  Install the **System2 Extension**.
4.  Place `shavit-getmap-system2.smx` into your `addons/sourcemod/plugins` directory (or the main plugins directory).
5.  Install **7-Zip** on your server.
    *   **Linux (Debian/Ubuntu)**: `sudo apt-get install p7zip-full`
    *   Ensure `7z` is in your PATH or configure the path in the cvar.
6.  Restart the server or load the plugin manually.

## ConVars

*   `gm_public_url` - Replace with a public FastDL URL containing maps for your respective game (default: `https://main.fastdl.me/maps/`).
*   `gm_maps_path` - Path to where the decompressed map file will go to (default: `maps/`).
*   `gm_fastdl_path` - Path to where the compressed map file will go to (default: `maps/`).
*   `gm_replace_map` - Specifies whether or not to replace the map if it already exists (default: `0`).
*   `gm_map_prefix` - Use map prefix before every map name.
*   `gm_delete_bz2_after` - Whether to delete the .bz2 after decompressing it (default: `1`).
*   `gm_7zip_binary` - Path to the 7-zip executable (default: `7z`).
*   `gm_map_list_url` - URL to the plain text file containing the list of available maps. (default: `https://main.fastdl.me/maps_index.html.txt`)
*   `gm_sjtiered_map_list_url` - URL to the plain text file containing the list of available tiered maps. (default: `https://lodgegaming.com.tr/sjtieredmaps.txt`)

## Commands

*   `sm_getmap <mapname>` - Download a map.
*   `sm_maplist` - List available maps from FastDL.
*   `sm_findmap <partial name>` - Search for a map.
*   `sm_delmap <mapname>` - Delete a map.
*   `sm_sjtieredmaps` - List available tiered maps from SourceJump.
