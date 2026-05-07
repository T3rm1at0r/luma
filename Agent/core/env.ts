export interface ProcessInfo {
    platform: Platform;
    arch: Architecture;
    pointerSize: number;
    mainModule: ModuleInfo;
}

export interface ModuleInfo {
    name: string;
    path: string;
    base: string;
    size: number;
}

export function getProcessInfo(): ProcessInfo {
    const main = Process.mainModule;
    return {
        platform: Process.platform,
        arch: Process.arch,
        pointerSize: Process.pointerSize,
        mainModule: {
            name: main.name,
            path: main.path,
            base: main.base.toString(),
            size: main.size,
        },
    };
}
