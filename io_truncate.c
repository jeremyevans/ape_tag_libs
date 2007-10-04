#include <stdio.h>
#include <unistd.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/* From liolib.c */
#define topfile(L)      ((FILE **)luaL_checkudata(L, 1, LUA_FILEHANDLE))
static FILE *tofile (lua_State *L) {
  FILE **f = topfile(L);
  if (*f == NULL)
    luaL_error(L, "attempt to use a closed file");
  return *f;
}

static int lua_io_truncate(lua_State *L) {
    FILE* file = tofile(L);
    off_t offset = luaL_optlong(L, 2, -1);
    int fd = fileno(file);
    if(offset < 0) {
        luaL_error(L, "Offset not provided, wrong type, or negative");
    }
    if(ftruncate(fd, offset)) {
        luaL_error(L, "Truncate not successful");
    }
    return 0;
}

static const struct luaL_reg io_truncate [] = {
    {"truncate", lua_io_truncate},
    {NULL, NULL}
};

int luaopen_io_truncate(lua_State *L) {
    luaL_openlib(L, "io", io_truncate, 0);
    return 1;
}
