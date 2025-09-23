package com.example.smartcampusid;

import io.flutter.app.FlutterApplication;
import io.flutter.FlutterInjector;

public class FlutterMultiDexApplication extends FlutterApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        FlutterInjector.instance().flutterLoader().startInitialization(this);
    }
}