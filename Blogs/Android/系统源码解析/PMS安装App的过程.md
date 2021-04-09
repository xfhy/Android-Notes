
### 前置知识

#### 包管理机制

所谓包，其实是一种文件格式，比如apk包、jar包等。包管理者一个职能就是识别不同的包，维护这些包的信息。当有一个新的包进入或离开Android世界，都需要向包管理者申报一下，其他管理部分要获取包的具体信息，也都需要向包管理者申请。包管理机制的核心是PackageManagerService(下文称PMS)，它负责对包进行管理。

#### apk的安装方法

1. 开机过程中安装：系统在每次开机会安装系统应用
2. adb工具安装：adb命令安装apk
3. 手动安装：平时下载的apk，通过系统安装器PackageInstaller（它是系统内置的应用程序，用于安装和卸载应用程序）来安装apk，是有安装界面的
4. 商店应用安装：商店上安装app，没有安装界面

#### PackageInstaller

它是安卓的一个系统app，用来安装和卸载app的。

### 安装

我们主要来分析一下手动安装apk的情况，系统会打开一个安装界面，我们可以继续安装和取消，应该大家都比较熟悉。这个界面就是PackageInstaller这个app中的PackageInstallerActivity。

#### 安装之前的过程

当我们点击安装的时候，会跳转到另一个界面InstallInstalling，最终会将需要安装的apk信息通过PackageInstallerSession传给PMS。

```java
//PackageInstallerSession.java
private void installNonStagedLocked(List<PackageInstallerSession> childSessions)
        throws PackageManagerException {
    final PackageManagerService.ActiveInstallSession installingSession =
            makeSessionActiveLocked();
    if (installingSession == null) {
        return;
    }
    ...
    //这里的mPm是PMS
    mPm.installStage(installingSession);
}
```

从这里开始，就来到了PMS，installStage()方法就是正式安装apk的过程了。整个apk的安装过程大致分为2步：

1. 拷贝安装包
2. 装载代码

#### 拷贝安装包

直接杀到PMS的installStage方法，看看流程是什么样的

```java
//PackageManagerService.java
void installStage(ActiveInstallSession activeInstallSession) {
    ...
    //注释1 Message的what是INIT_COPY
    final Message msg = mHandler.obtainMessage(INIT_COPY);
    //注释2 初始化一个InstallParams，并传入安装包的相关数据
    final InstallParams params = new InstallParams(activeInstallSession);
    params.setTraceMethod("installStage").setTraceCookie(System.identityHashCode(params));
    //注释3 Message的obj是InstallParams
    msg.obj = params;
    ...
    mHandler.sendMessage(msg);
}
```

注意到，上面的代码只不过是发了个消息，我们看看是怎么处理这条消息的

```java
//PackageManagerService.java
void doHandleMessage(Message msg) {
    switch (msg.what) {
        case INIT_COPY: {
            //上面说了Message的obj是InstallParams
            HandlerParams params = (HandlerParams) msg.obj;
            if (params != null) {
                params.startCopy();
            }
            break;
        }
        ...
    }
}
```

把Message的obj取出来，实际上就是之前传入的InstallParams，直接去InstallParams的startCopy()方法

```java
//PackageManagerService.java
private abstract class HandlerParams {
    final void startCopy() {
        handleStartCopy();
        handleReturnCode();
    }

    abstract void handleStartCopy();
    abstract void handleReturnCode();
}
```

原来InstallParams自己并没有实现startCopy方法，而是由父类HandlerParams实现的，里面只有2个抽象方法，这2个抽象方法都是子类去实现的。这里其实用到了一种设计模式，叫模板方法。下面我们继续看handleStartCopy()和handleReturnCode()的子类实现，先看handleStartCopy()。

```java
//PackageManagerService.java
class InstallParams extends HandlerParams {
    public void handleStartCopy() {
        int ret = PackageManager.INSTALL_SUCCEEDED;
    
        // If we're already staged, we've firmly committed to an install location
        //决定安装位置是内部存储空间还是sdcard中，从这里看来Android 11是只允许安装在内部存储空间里面了
        //老的源码中还有一个PackageManager.INSTALL_EXTERNAL表示是安装在sdcard中，现在这个常量已经没了。
        if (origin.staged) {
            if (origin.file != null) {
                installFlags |= PackageManager.INSTALL_INTERNAL;
            } else {
                throw new IllegalStateException("Invalid stage location");
            }
        }
        ...
        
        //创建安装参数对象 InstallArgs
        final InstallArgs args = createInstallArgs(this);
        mVerificationCompleted = true;
        mIntegrityVerificationCompleted = true;
        mEnableRollbackCompleted = true;
        mArgs = args;
    
        ...
    
        mRet = ret;
    }
}
```

在handleStartCopy()方法中，我们只需要知道它创建了安装参数对象InstallArgs即可。然后在handleReturnCode()方法中会用到它

```java
//PackageManagerService.java
class InstallParams extends HandlerParams {
    @Override
    void handleReturnCode() {
        if (mVerificationCompleted
                && mIntegrityVerificationCompleted && mEnableRollbackCompleted) {
            if ((installFlags & PackageManager.INSTALL_DRY_RUN) != 0) {
                String packageName = "";
                ParseResult<PackageLite> result = ApkLiteParseUtils.parsePackageLite(
                        new ParseTypeImpl(
                                (changeId, packageName1, targetSdkVersion) -> {
                                    ApplicationInfo appInfo = new ApplicationInfo();
                                    appInfo.packageName = packageName1;
                                    appInfo.targetSdkVersion = targetSdkVersion;
                                    return mPackageParserCallback.isChangeEnabled(changeId,
                                            appInfo);
                                }).reset(),
                        origin.file, 0);
                if (result.isError()) {
                    Slog.e(TAG, "Can't parse package at " + origin.file.getAbsolutePath(),
                            result.getException());
                } else {
                    packageName = result.getResult().packageName;
                }
                try {
                    observer.onPackageInstalled(packageName, mRet, "Dry run", new Bundle());
                } catch (RemoteException e) {
                    Slog.i(TAG, "Observer no longer exists.");
                }
                return;
            }
            if (mRet == PackageManager.INSTALL_SUCCEEDED) {
                //调用InstallArgs的copyApk()方法，复制apk文件，具体实现在子类FileInstallArgs
                mRet = mArgs.copyApk();
            }
            //安装流程
            processPendingInstall(mArgs, mRet);
        }
    }
}
```

利用之前创建好的InstallArgs对象，实际是其子类FileInstallArgs类型，然后调用其copyApk方法进行安装包的拷贝操作。

```java
//PackageManagerService.java
class FileInstallArgs extends InstallArgs {
    // Example topology:
    // /data/app/com.example/base.apk
    // /data/app/com.example/split_foo.apk
    // /data/app/com.example/lib/arm/libfoo.so
    // /data/app/com.example/lib/arm64/libfoo.so
    // /data/app/com.example/dalvik/arm/base.apk@classes.dex
    
    int copyApk() {
        return doCopyApk();
    }
    private int doCopyApk() {
        ...

        //创建存储安装包的目标路径，实际上是/data/app/应用包名目录
        final File tempDir =
                mInstallerService.allocateStageDirLegacy(volumeUuid, isEphemeral);
        
        //将安装包apk拷贝到目标路径中
        int ret = PackageManagerServiceUtils.copyPackage(
                origin.file.getAbsolutePath(), codeFile);
        
        ...
        //将apk中的动态库.so文件也拷贝到目标路径中
        handle = NativeLibraryHelper.Handle.create(codeFile);
        ret = NativeLibraryHelper.copyNativeBinariesWithOverride(handle, libraryRoot,
                abiOverride, isIncremental);

        return ret;
    }
}
```

在FileInstallArgs的copyApk方法中调用doCopyApk方法，主要干的事情就是3个：首先创建安装包的目标路径，方便待会儿复制到这里来，它的实际路径是`/data/app/com.example`；其次将安装包apk拷贝到目标路径中；最后是将apk中的动态库.so文件也拷贝到目标路径中。其实现都是一些IO的操作，就不继续往下看了。

安装包在这一步骤完成之后，就存在于`/data/app/com.example/base.apk`中了，到这里安装包的拷贝工作是完成了。

#### 装载代码

在上面InstallParams#handleReturnCode()中，调用processPendingInstall方法处理安装：

```java
//PackageManagerService.java
private void processPendingInstall(final InstallArgs args, final int currentStatus) {
    if (args.mMultiPackageInstallParams != null) {
        args.mMultiPackageInstallParams.tryProcessInstallRequest(args, currentStatus);
    } else {
        PackageInstalledInfo res = createPackageInstalledInfo(currentStatus);
        //异步处理安装过程
        processInstallRequestsAsync(
                res.returnCode == PackageManager.INSTALL_SUCCEEDED,
                Collections.singletonList(new InstallRequest(args, res)));
    }
}

// Queue up an async operation since the package installation may take a little while.
private void processInstallRequestsAsync(boolean success,
        List<InstallRequest> installRequests) {
    mHandler.post(() -> {
        if (success) {
            //预安装，检查包状态，确保环境是ok的，如果不ok，那么会清理拷贝的文件
            for (InstallRequest request : installRequests) {
                request.args.doPreInstall(request.installResult.returnCode);
            }
            //安装，调用installPackageTracedLI进行安装
            synchronized (mInstallLock) {
                installPackagesTracedLI(installRequests);
            }
            //安装收尾工作
            for (InstallRequest request : installRequests) {
                request.args.doPostInstall(
                        request.installResult.returnCode, request.installResult.uid);
            }
        }
        //内部会生成一个POST_INSTALL消息给PackageHanlder
        for (InstallRequest request : installRequests) {
            restoreAndPostInstall(request.args.user.getIdentifier(), request.installResult,
                    new PostInstallData(request.args, request.installResult, null));
        }
    });
}
```

安装过程是放子线程里面进行的，这里的mHandler用的不是主线程的Looper，而是一个HandlerThread里面的Looper。大致处理流程如下：

1. 预安装：检查当前安装包的状态，确保安装环境正常，如果安装环境有问题会清理拷贝文件
2. 安装：真正的安装阶段在installPackagesTracedLI方法中，在里面添加跟踪Trace，最后是调用的installPackageLI进行安装
3. 安装收尾工作：检查状态，如果安装不成功，删除掉相关目录文件
4. 通知操作：发送`POST_INSTALL`消息，然后通过广播、回调接口等方式通知系统中的其他组件，有新的Package安装或发生了改变

所以说installPackagesTracedLI是安装apk的核心代码：

```java
//PackageManagerService.java
private void installPackagesTracedLI(List<InstallRequest> requests) {
    ...
    installPackagesLI(requests);
}
 
private void installPackagesLI(List<InstallRequest> requests) {
    ...
    //注释1 Prepare 准备：分析任何当前安装状态，分析包并对其进行初始验证.检查SDK版本、静态库等；检查签名；设置权限；
    prepareResult = preparePackageLI(request.args, request.installResult);
    ...
    //注释2 Scan 扫描：prepare中收集的上下文，询问已分析的包。
    final List<ScanResult> scanResults = scanPackageTracedLI(
                            prepareResult.packageToScan, prepareResult.parseFlags,
                            prepareResult.scanFlags, System.currentTimeMillis(),
                            request.args.user);
    ...
    //注释3 Reconcile 调和：在彼此的上下文和当前系统状态中验证扫描的包，以确保安装成功。
    ReconcileRequest reconcileRequest = new ReconcileRequest(preparedScans, installArgs,
            installResults,
            prepareResults,
            mSharedLibraries,
            Collections.unmodifiableMap(mPackages), versionInfos,
            lastStaticSharedLibSettings);
    ...
    //注释4 Commit 提交：提交所有扫描的包并更新系统状态。这是安装流中唯一可以修改系统状态的地方，必须在此阶段之前确定所有可预测的错误。
    commitPackagesLocked(commitRequest);
    ...
    //注释5 完成APK的安装
    executePostCommitSteps(commitRequest);
}
```

installPackagesLI()方法内部非常复杂，上面简单调了一些主流程拿出来。

1. Prepare准备：分析任何当前安装状态，分析包并对其进行初始验证。
    1. 在这一阶段首先是将apk文件解析出来，解析它的AndroidManifest.xml文件，将结果记录起来。我们平时在清单文件中声明的Activity等组件就是在这一步被记录到Framework中的，后续才能通过startActivity等方式启动来
    2. 然后是对签名信息进行验证
    3. 设置相关权限
    4. 生成安装包abi
    5. dex优化，实际为dex2oat操作，将apk中的dex文件转换为oat文件
2. Scan扫描：考虑到prepare中收集的上下文，询问已分析的包
3. Reconcile调和：在彼此的上下文和当前系统状态中验证扫描的包，以确保安装成功
4. Commit提交：提交所有扫描的包并更新系统状态。这是安装流中唯一可以修改系统状态的地方，必须在此阶段之前确定所有可预测的错误
5. 完成APK的安装，再次执行dex优化（如有必要），然后将apk的安装操作交给installed进程进行apk的安装

#### 小结

首先将apk的信息交给PMS进行处理，然后拷贝apk，然后装载代码，最后交给installed进程来完成安装。

### 参考资料

- [APP的安装过程](https://shuwoom.com/?p=60)
- [应用程序安装流程](https://maoao530.github.io/2017/01/18/package-install/)
- [Android包管理机制（一）PackageInstaller的初始化](http://liuwangshu.cn/framework/pms/1-packageinstaller-initialize.html)
- [APK安装流程详解12——PMS中的新安装流程上(拷贝)](https://cloud.tencent.com/developer/article/1199459)
- [Android10_原理机制系列_PMS的启动及应用的安装过程](https://www.cnblogs.com/fanglongxiang/p/13817369.html)
- [Android 10.0 PackageManagerService（四）APK安装流程-[Android取经之路]](https://blog.csdn.net/yiranfeng/article/details/104073200)