# Keep AudioProcess methods called from JNI native code
-keepclassmembers class com.qumolangmo.wecho.AudioProcess {
    public void notifyScriptCompileError(java.lang.String);
}
