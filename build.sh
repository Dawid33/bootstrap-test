#!/bin/sh

(
    echo "Bootstrapping tcc, lua and musl..."
    cd bootstrap-base && make -S
    echo "Finished bootstrapping."
)


CC=../bootstrap-base/05/output/bin/tcc
CFLAGS="-nostdinc -I ../bootstrap-base/05/output/include -I ../src/include -I ../lua/include -B../bootstrap-base/05/tcc-0.9.27/tcc0-files"
LDFLAGS="-L../bootstrap-base/05/output/lib -L../lua/lib -B../bootstrap-base/05/tcc-0.9.27/tcc0-files"

mkdir -p build
cd build

# Compile
$CC $CFLAGS -c ../src/main.c
$CC $CFLAGS -c ../src/other.c

# Link
$CC $LDFLAGS -o ../cc main.o other.o

cd .. && rm -r build