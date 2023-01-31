go:
	cd aubiogo && go build -v
	cd soxgo && go build -v
	cd oscnotify && go build -v

cjson:
	echo "note: requires liblua5.3-dev"
	rm -rf lua-cjson
	git clone --depth 1 https://github.com/mpx/lua-cjson.git
	cd lua-cjson && cc -c -O3 -Wall -pedantic -DNDEBUG  -I/usr/include/lua5.3 -fpic -o lua_cjson.o lua_cjson.c
	cd lua-cjson && cc -c -O3 -Wall -pedantic -DNDEBUG  -I/usr/include/lua5.3 -fpic -o strbuf.o strbuf.c
	cd lua-cjson && cc -c -O3 -Wall -pedantic -DNDEBUG  -I/usr/include/lua5.3 -fpic -o fpconv.o fpconv.c
	cd lua-cjson && cc  -shared -o cjson.so lua_cjson.o strbuf.o fpconv.o
	cp lua-cjson/cjson.so .
	rm -rf lua-cjson

all: go cjson
	git update-index --assume-unchanged soxgo/soxgo
	git update-index --assume-unchanged cjson.so

