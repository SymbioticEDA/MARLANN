all:
	$(MAKE) -C asm
	$(MAKE) -C sim

clean:
	$(MAKE) -C asm clean
	$(MAKE) -C sim clean
