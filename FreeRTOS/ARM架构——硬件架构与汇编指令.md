
### 1.汇编指令

- 读内存：Load
```
	#示例
	LDR R0, [R1, #4] ;读地址“R1+4”，得到4字节数据存入R0
	#LDRB：1byte
	#LDRH: 2bytes
	#LDRD: 8bytes
```
- 写内存：Stroe
```
	#示例
	STR RO，[R1，#4] 把R0的4字节数据写入地址"R1+4"
	#STR B：1byte
	#STR H: 2bytes
```
- 加减
```
	ADD R0, R1, R2R0=R1+R2
	ADD R0,RO，#1RO=R0+1
	SUB RO,R1, R2R0=R1-R2
	SUB RO, RO,#1R0=R0-1
```
- 比较
```
	CMP RO， R1 ； 结果保存在PSR(程序状态寄存器)
```
- 跳转
```
	B  main ; Branch，直接跳转
	BL main ; Branch and Link， 先把返回地址保存在LR寄存器里再跳转
```
### 2.C函数的反汇编

c函数：
```
int add(volatile int a, volatile int b)
{
	volatile int sum;
	sum = a + b;
	return sum;
}
```
**volatile ：不要让编译器优化程序

反汇编：
![[image.png]]
    地址                机器码                                       汇编码
