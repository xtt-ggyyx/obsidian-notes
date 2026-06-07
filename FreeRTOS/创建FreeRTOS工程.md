#### 问题1：cubemx生成代码编译报错

报错信息：
../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2/freertos_os2.h(31): error:  #13: expected a file name

问题解决：修改cubemx配置，将V1.8.6改选为V1.8.5后编译不再报错
参考网页：[FreeRTOS/Source/CMSIS_RTOS_V2/freertos_os2.h(31): error: #13: expected a file name报错-CSDN博客](https://blog.csdn.net/jacklood/article/details/141466312)
