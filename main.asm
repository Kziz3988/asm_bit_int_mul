.386
.model flat, stdcall
option casemap:none

include windows.inc
include msvcrt.inc
include Kernel32.inc
include User32.inc
includelib msvcrt.lib
includelib Kernel32.lib
includelib User32.lib

printf PROTO C, :ptr byte, :vararg
scanf PROTO C, :ptr byte, :vararg

.data?
num1Size dd ?
num2Size dd ?
lpNum1 dd ?
lpNum2 dd ?
lpProduct dd ?
lpDraft dd ?
carry db ?
longCarry dd ?
temp1 dd ?
temp2 db ?
temp3 dd ?
loopVar dd ?

.data
szInputMsg1 db "请输入数字1的位数", 0AH, 0
szInputMsg2 db "请输入数字2的位数", 0AH, 0
szInputMsg3 db "请输入数字1", 0AH, 0
szInputMsg4 db "请输入数字2", 0AH, 0
szAllocFailedMsg db "数字过大，内存分配失败！", 0AH, 0 ;经测试，支持两数之和共1.6亿位数字相乘
szConvertFailedMsg db "输入的数字不合法！", 0AH, 0 ;一般是输入0~9外的字符或数字长度不足
szOutputMsg db "乘积如下", 0AH, 0
szIntFormat db "%d", 0
szStrFormat db "%s", 0
szCharFormat db "%c", 0
szNewline db 0AH, 0

.code
;将字符串转换为整数，每个数位占一个字节
StrToInt proc uses eax ebx ecx lpStr: dword, len:dword
	mov ecx, 0
	mov ebx, lpStr
	convert:
		mov al, byte ptr[ebx + ecx]
		cmp al, 48
		jb convert_error
		cmp al, 57
		ja convert_error
		sub al, 48
		mov byte ptr[ebx + ecx], al
		inc ecx
		cmp ecx, len
		jb convert
	ret
	convert_error:
		invoke printf, offset szConvertFailedMsg
		invoke ExitProcess, 1
		ret
StrToInt endp

;打印竖式
PrintDraft proc uses eax ebx ecx edx
	mov loopVar, 0
	mov eax, num1Size
	add eax, num2Size
	mov temp3, eax
	print_draft:
		mov ebx, 0
		print_line:
			mov eax, loopVar
			mul temp3
			add eax, ebx
			mov edx, lpDraft
			mov al, byte ptr[edx + eax]
			invoke printf, offset szIntFormat, al
			inc ebx
			cmp ebx, temp3
			jb print_line
		invoke printf, offset szNewline
		inc loopVar
		mov ecx, loopVar
		cmp ecx, num2Size
		jb print_draft
	ret
PrintDraft endp

;计算lpNum指向的整数乘以一位数factor，并将乘积存入lpProd指向的位置
OneDigitMul proc uses eax ebx ecx edx edi lpNum: dword, len: dword, shift: dword, factor: byte, lpProd: dword
	mov ecx, len
	mov carry, 0
	cal_mul:
		dec ecx
		xor eax, eax
		mov ebx, lpNum
		mov al, byte ptr[ebx + ecx]
		mul factor
		add al, carry

		xor edx, edx
		mov edi, 10
		div edi
		mov ebx, lpProd
		add ebx, shift
		inc ebx
		mov byte ptr[ebx + ecx], dl
		mov carry, al

		test ecx, ecx
		jnz cal_mul
	
	mov ebx, lpProd
	add ebx, shift
	mov dl, carry
	mov byte ptr[ebx + ecx], dl
	ret
OneDigitMul endp

main proc
	;分配内存
	invoke GetProcessHeap ;获取进程堆句柄
	mov ebx, eax

	invoke printf, offset szInputMsg1
	invoke scanf, offset szIntFormat, offset num1Size
	invoke HeapAlloc, ebx, HEAP_ZERO_MEMORY, num1Size
	test eax, eax
	jz alloc_failed
	mov lpNum1, eax

	invoke printf, offset szInputMsg2
	invoke scanf, offset szIntFormat, offset num2Size
	invoke HeapAlloc, ebx, HEAP_ZERO_MEMORY, num2Size
	test eax, eax
	jz alloc_failed
	mov lpNum2, eax

	mov eax, num1Size
	add eax, num2Size
	invoke HeapAlloc, ebx, HEAP_ZERO_MEMORY, eax ;乘积的位数至多为两个因数的位数之和
	test eax, eax
	jz alloc_failed
	mov lpProduct, eax

	xor edx, edx
	mov eax, num1Size
	add eax, num2Size
	mul num2Size
	invoke HeapAlloc, ebx, HEAP_ZERO_MEMORY, eax ;竖式乘法需要(num1Size + num2Size) * num2Size的缓冲区
	test eax, eax
	jz alloc_failed
	mov lpDraft, eax

	jmp alloc_success

	alloc_failed:
		invoke printf, offset szAllocFailedMsg
		invoke ExitProcess, 1

	alloc_success:
	;输入数字
		invoke printf, offset szInputMsg3
		invoke scanf, offset szStrFormat, [lpNum1]
		invoke printf, offset szInputMsg4
		invoke scanf, offset szStrFormat, [lpNum2]
		invoke StrToInt, lpNum1, num1Size
		invoke StrToInt, lpNum2, num2Size

	;进行乘法运算
	mov ecx, num2Size
	mov loopVar, ecx
	multiply:
		dec loopVar
		mov eax, num1Size
		add eax, num2Size
		mov ebx, num2Size
		sub ebx, loopVar
		dec ebx
		mul ebx
		mov temp1, eax
		mov ebx, lpNum2
		mov ecx, loopVar
		mov al, byte ptr[ebx + ecx]
		mov temp2, al
		mov edx, lpDraft
		add edx, temp1
		invoke OneDigitMul, lpNum1, num1Size, loopVar, temp2, edx
		mov ecx, loopVar
		test ecx, ecx
		jnz multiply

	;将竖式各位求和得到乘积
	mov longCarry, 0
	mov eax, num1Size
	add eax, num2Size
	mov temp3, eax
	mov loopVar, eax
	sum:
		dec loopVar
		mov temp1, 0

		sum_digit:
			mov eax, temp3
			mul temp1
			add eax, lpDraft
			mov ebx, eax
			mov ecx, loopVar
			movzx eax, byte ptr[ebx + ecx]
			add longCarry, eax

			inc temp1
			mov edx, temp1
			cmp edx, num2Size
			jb sum_digit

		xor edx, edx
		mov eax, longCarry
		mov ebx, 10
		div ebx
		mov longCarry, eax
		mov ebx, lpProduct
		mov ecx, loopVar
		mov byte ptr[ebx + ecx], dl

		mov ecx, loopVar
		test ecx, ecx
		jnz sum

	;此时进位必定为0，无需再进行进位操作
	;输出乘积
	invoke printf, offset szOutputMsg
	mov loopVar, 0
	mov ebx, lpProduct
	mov temp2, 0
	print_prod:
		mov ecx, loopVar
		mov al, byte ptr[ebx + ecx]
		test al, al
		jnz print_digit
		mov dl, temp2
		test dl, dl
		jz print_next ;不打印前导0
	print_digit:
		mov temp2, 1
		invoke printf, offset szIntFormat, al
	print_next:
		inc loopVar
		mov ecx, loopVar
		cmp ecx, temp3
		jb print_prod

	cmp temp2, 0
	jnz end_proc
	;若乘积为0，则打印0作为结果
	invoke printf, offset szIntFormat, temp2

end_proc:
	;invoke printf, offset szNewline
	;invoke PrintDraft
	invoke ExitProcess, 0
	ret
main endp
end main