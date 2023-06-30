TCCDIR=tcc-0.9.27
MUSLDIR=musl-0.6.0
TCC=$(TCCDIR)/tcc
TCC0=$(TCC)0
TCC1=$(TCC)1
TCCINST=$(TCCDIR)/tcc0-files
TCCFINAL=output
all: out04 a.out README.html tcc
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
$(TCCINST)/libtcc1.a: $(TCC0) $(TCCDIR)/lib/*.[cS]
	mkdir -p $(TCCINST)/include
	$(TCC0) -c $(TCCDIR)/lib/alloca86_64-bt.S -o $(TCCDIR)/lib/alloca86_64-bt.o
	$(TCC0) -c $(TCCDIR)/lib/alloca86_64.S -o $(TCCDIR)/lib/alloca86_64.o
	$(TCC0) -c $(TCCDIR)/lib/va_list.c -o $(TCCDIR)/lib/va_list.o
	$(TCC0) -c $(TCCDIR)/lib/libtcc1.c -o $(TCCDIR)/lib/libtcc1.o
	$(TCC0) -ar $(TCCINST)/libtcc1.a $(TCCDIR)/lib/*.o
	cp -r $(TCCDIR)/include/*.h $(TCCINST)/include/
	# for lua
	cp -r $(TCCINST) ../06/src/tcc0-files
$(TCC1): $(TCC0) $(TCCINST)/libtcc1.a
	cd $(TCCDIR) && ./tcc0 tcc.c -o tcc1

$(TCCFINAl)/lib/libtcc1.a: $(TCC1) $(TCCDIR)/lib/*.[cS]
	mkdir -p $(TCCFINAL)/lib
	$(TCC1) -c $(TCCDIR)/lib/alloca86_64-bt.S -o $(TCCDIR)/lib/alloca86_64-bt.o
	$(TCC1) -c $(TCCDIR)/lib/alloca86_64.S -o $(TCCDIR)/lib/alloca86_64.o
	$(TCC1) -c $(TCCDIR)/lib/va_list.c -o $(TCCDIR)/lib/va_list.o
	$(TCC1) -c $(TCCDIR)/lib/libtcc1.c -o $(TCCDIR)/lib/libtcc1.o
	$(TCC1) -ar $(TCCFINAL)/lib/libtcc1.a $(TCCDIR)/lib/*.o
$(TCCFINAL)/bin/tcc: $(TCC1)
	cd $(TCCDIR) && ./tcc1 tcc.c -o tcc2
	mkdir -p $(TCCFINAL)/bin && cp $(TCCDIR)/tcc2 $(TCCFINAL)/bin/tcc
tcc: $(TCCFINAL)/bin/tcc $(TCCFINAl)/lib/libtcc1.a
	mkdir -p $(TCCFINAL)/include
	cp -r $(TCCDIR)/include/*.h output/include/

clean:
	rm -rf output 
	rm -rf ../06/src/tcc0-files
	rm -f out* README.html *.out *.o $(TCCDIR)/tcc[0123456] $(TCCDIR)/tcc[0123456]a $(TCCDIR)/lib/*.[oa] 
