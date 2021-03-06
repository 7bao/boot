         ;代码清单13-1
         ;文件名：c13_mbr.asm
         ;文件说明：硬盘主引导扇区代码 
         ;创建日期：2011-10-28 22:35        ;设置堆栈段和栈指针 

         core_base_address equ 0x00040000   ;常数，内核加载的起始内存地址 
         core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号 
         
	 mov al,0x13
	 mov ah,0x00
	 int 0x10

         mov ax,cs      
         mov ss,ax
         mov sp,0x7c00
      
         ;计算GDT所在的逻辑段地址
         mov eax,[cs:pgdt+0x7c00+0x02]      ;GDT的32位物理地址 
         xor edx,edx
         mov ebx,16
         div ebx                            ;分解成16位逻辑地址 

         mov ds,eax                         ;令DS指向该段以进行操作
         mov ebx,edx                        ;段内起始偏移地址 

         ;跳过0#号描述符的槽位 
         ;创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间
         mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
         mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

         ;创建保护模式下初始代码段描述符
         mov dword [ebx+0x10],0x7c00ffff    ;基地址为0x00007c00，界限0x1FF 
         mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 

         ;建立保护模式下的堆栈段描述符      ;基地址为0x00007C00，界限0xFFFFE 
         mov dword [ebx+0x18],0x7c00fffe    ;粒度为4KB 
         mov dword [ebx+0x1c],0x00cf9600
         
         ;建立保护模式下的显示缓冲区描述符   
         mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
         mov dword [ebx+0x24],0x0040920b    ;粒度为字节

     	 mov dword [ebx+0x28],0x0000ffff
     	 mov dword [ebx+0x2c],0x00409804
         
         ;初始化描述符表寄存器GDTR
         mov word [cs: pgdt+0x7c00],47      ;描述符表的界限   
 
         lgdt [cs: pgdt+0x7c00]
      
         in al,0x92                         ;南桥芯片内的端口 
         or al,0000_0010B
         out 0x92,al                        ;打开A20

         cli                                ;中断机制尚未工作

         mov eax,cr0
         or eax,1
         mov cr0,eax                        ;设置PE位
      
         ;以下进入保护模式... ...
         jmp dword 0x0010:flush             ;16位的描述符选择子：32位偏移
                                            ;清流水线并串行化处理器
         [bits 32]               
  flush:                                  
         mov eax,0x0008                     ;加载数据段(0..4GB)选择子
         mov ds,eax
      
         mov eax,0x0018                     ;加载堆栈段选择子 
         mov ss,eax
         xor esp,esp                        ;堆栈指针 <- 0 
         
         ;以下加载系统核心程序 
         mov edi,core_base_address 
      
         mov eax,core_start_sector
         mov ebx,edi                        ;起始地址 
         call read_hard_disk_0              ;以下读取程序的起始部分（一个扇区） 
      
         ;以下判断整个程序有多大
         mov eax,[edi]                      ;核心程序尺寸
         xor edx,edx 
         mov ecx,512                        ;512字节每扇区
         div ecx

         or edx,edx
         jnz @1                             ;未除尽，因此结果比实际扇区数少1 
         dec eax                            ;已经读了一个扇区，扇区总数减1 
   @1:
         or eax,eax                         ;考虑实际长度≤512个字节的情况 
         jz setup                           ;EAX=0 ?

         ;读取剩余的扇区
         mov ecx,eax                        ;32位模式下的LOOP使用ECX
         mov eax,core_start_sector
         inc eax                            ;从下一个逻辑扇区接着读
   @2:
         call read_hard_disk_0
         inc eax
         loop @2                            ;循环读，直到读完整个内核 

 setup:
         jmp 0x28:0x4
       
;-------------------------------------------------------------------------------
read_hard_disk_0:                        ;从硬盘读取一个逻辑扇区
                                         ;EAX=逻辑扇区号
                                         ;DS:EBX=目标缓冲区地址
                                         ;返回：EBX=EBX+512 
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                       ;读取的扇区数

         inc dx                          ;0x1f3
         pop eax
         out dx,al                       ;LBA地址7~0

         inc dx                          ;0x1f4
         mov cl,8
         shr eax,cl			; 右移指令
         out dx,al                       ;LBA地址15~8

         inc dx                          ;0x1f5
         shr eax,cl
         out dx,al                       ;LBA地址23~16

         inc dx                          ;0x1f6
         shr eax,cl
         or al,0xe0                      ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                          ;0x1f7
         mov al,0x20                     ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                      ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                     ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         ret
      
;-------------------------------------------------------------------------------
         pgdt             dw 0
                          dd 0x00007e00      ;GDT的物理地址
         jump_adr         dd 0x0004000a
;-------------------------------------------------------------------------------                             
         times 510-($-$$) db 0
                          db 0x55,0xaa
