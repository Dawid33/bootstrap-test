#include <stdio.h>
#include <string.h>
// #include <lua.h>
// #include <lauxlib.h>
// #include <lualib.h>
#include "mytest.h"

int main (void) {
    myprint();
    // char buff[256];
    // int error;
    // lua_State *L = lua_open();   /* opens Lua */
    // luaL_openlibs(L);

    // while (fgets(buff, sizeof(buff), stdin) != NULL) {
    //     error = luaL_loadbuffer(L, buff, strlen(buff), "line") || lua_pcall(L, 0, 0, 0);
    //     if (error) {
    //         fprintf(stderr, "%s", lua_tostring(L, -1));
    //         lua_pop(L, 1);  /* pop error message from the stack */
    //     }
    // }

    // lua_close(L);
    return 0;
}
