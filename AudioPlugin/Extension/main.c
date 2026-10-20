// Apple's extension entry point is provided by Foundation.
extern int NSExtensionMain(int argc, const char *argv[]);
extern void SwiftAudioPluginInitialize(void);
int main(int argc, const char *argv[]) {
    SwiftAudioPluginInitialize();
    return NSExtensionMain(argc, argv);
}
