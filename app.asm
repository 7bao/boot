dd len

extern show
global _start

_start:
         [bits 32]
         mov eax, 0x8 			;data segment (0-4GB)
    	 mov es,eax
    	 mov ds,eax
       	 mov dword [es:0x0b8004],0x072e074c  ;char "L"
	 call show
         hlt
len:
