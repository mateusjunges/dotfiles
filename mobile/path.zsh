# Android SDK (installed by Android Studio on first launch)
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# JDK 17 for Android command-line builds (installed via Brewfile: temurin@17)
if [ -x /usr/libexec/java_home ]; then
  java17=$(/usr/libexec/java_home -v 17 2>/dev/null)
  if [ -n "$java17" ]; then
    export JAVA_HOME="$java17"
  fi
  unset java17
fi
