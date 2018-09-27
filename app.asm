dd len

extern show
global _start

_start:
         [bits 32]
         mov eax, 0x8 			;data segment (0-4GB)
    	 mov es,eax
    	 mov ds,eax

	 call show
         hlt
len:
