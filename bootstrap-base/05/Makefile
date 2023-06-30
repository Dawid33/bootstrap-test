TCCDIR=tcc-0.9.27
MUSLDIR=musl-0.6.0
TCC=$(TCCDIR)/tcc
TCC0=$(TCC)0
TCC2=$(TCC)2
TCCINST=$(TCCDIR)/tcc0-files
TCCFINAL=output
all: out04 a.out README.html $(TCC)2 # $(TCCFINAL)/bin/tcc $(TCCFINAL)/lib/libtcc1.a
in04: *.b ../04a/out04
	../04a/out04 main.b in04
out04: in04 ../04/out03
	../04/out03 in04 out04
%.html: %.md ../markdown
	../markdown $<
%.out: %.c *.h out04
	./out04 $< $@
a.out: main.c *.h out04
	./out04
test.out: test.s.o test.c.o
	$(TCC0) -static -nostdlib test.s.o test.c.o -o test.out
test.s.o: $(TCC0) test.s
	$(TCC0) -static -nostdlib -c test.s -o test.s.o
test.c.o: $(TCC0) test.c
	$(TCC0) -static -nostdlib -c test.c -o test.c.o
$(TCC0): $(TCCDIR)/*.c $(TCCDIR)/*.h out04
	cd $(TCCDIR) && ../out04 tcc.c tcc0
$(TCCINST)/lib/libtcc1.a: $(TCC0) $(TCCDIR)/lib/*.[cS]
	$(TCC0) -c $(TCCDIR)/lib/alloca86_64-bt.S -o $(TCCDIR)/lib/alloca86_64-bt.o
	$(TCC0) -c $(TCCDIR)/lib/alloca86_64.S -o $(TCCDIR)/lib/alloca86_64.o
	$(TCC0) -c $(TCCDIR)/lib/va_list.c -o $(TCCDIR)/lib/va_list.o
	$(TCC0) -c $(TCCDIR)/lib/libtcc1.c -o $(TCCDIR)/lib/libtcc1.o
	$(TCC0) -ar $(TCCDIR)/lib/libtcc1.a $(TCCDIR)/lib/*.o
$(TCC)1: $(TCC0) $(TCCINST)/lib/libtcc1.a
	cd $(TCCDIR) && ./tcc0 tcc.c -o tcc1
$(TCC2): $(TCC)1
	cd $(TCCDIR) && ./tcc1 tcc.c -o tcc2

# $(TCCFINAl)/lib/libtcc1.a: $(TCC)2 $(TCCDIR)/lib/*.[cS]
# 	mkdir -p $(TCCFINAL)/bin
# 	mkdir -p $(TCCFINAL)/include
# 	mkdir -p $(TCCFINAL)/lib
# 	$(TCC)2 -c $(TCCDIR)/lib/alloca86_64-bt.S -o $(TCCDIR)/lib/alloca86_64-bt.o
# 	$(TCC)2 -c $(TCCDIR)/lib/alloca86_64.S -o $(TCCDIR)/lib/alloca86_64.o
# 	$(TCC)2 -c $(TCCDIR)/lib/va_list.c -o $(TCCDIR)/lib/va_list.o
# 	$(TCC)2 -c $(TCCDIR)/lib/libtcc1.c -o $(TCCDIR)/lib/libtcc1.o
# 	$(TCC)2 -ar $(TCCDIR)/lib/libtcc1.a $(TCCDIR)/lib/*.o

# $(TCCFINAL)/bin/tcc: $(TCC)2
# 	cp ./tcc2 $(TCCFINAL)/bin/tcc

clean:
	cd $(TCCDIR) && make clean
	cd $(MUSLDIR) && make clean
	rm -rf output 
	rm -f out* README.html *.out *.o $(TCCDIR)/tcc[0123456] $(TCCDIR)/tcc[0123456]a $(TCCDIR)/lib/*.[oa] 
