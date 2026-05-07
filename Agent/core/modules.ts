export interface ModuleSymbolBundle {
    exports: ExportEntry[];
    imports: ImportEntry[];
    symbols: SymbolEntry[];
}

export interface ExportEntry {
    type: ModuleExportType;
    name: string;
    address: string;
}

export interface ImportEntry {
    type?: ModuleImportType;
    name: string;
    module?: string;
    address?: string;
    slot?: string;
}

export interface SymbolEntry {
    name: string;
    type: ModuleSymbolType;
    address: string;
    isGlobal: boolean;
    size?: number;
    sectionID?: string;
    sectionProtection?: PageProtection;
}

export function enumerateModuleSymbols(name: string): ModuleSymbolBundle {
    const module = Process.getModuleByName(name);

    return {
        exports: module.enumerateExports().map(e => ({
            type: e.type,
            name: e.name,
            address: e.address.toString(),
        })),
        imports: module.enumerateImports().map(i => {
            const out: ImportEntry = { name: i.name };
            if (i.type !== undefined) out.type = i.type;
            if (i.module !== undefined) out.module = i.module;
            if (i.address !== undefined) out.address = i.address.toString();
            if (i.slot !== undefined) out.slot = i.slot.toString();
            return out;
        }),
        symbols: module.enumerateSymbols().map(s => {
            const out: SymbolEntry = {
                name: s.name,
                type: s.type,
                address: s.address.toString(),
                isGlobal: s.isGlobal,
            };
            if (s.size !== undefined) out.size = s.size;
            if (s.section !== undefined) {
                out.sectionID = s.section.id;
                out.sectionProtection = s.section.protection;
            }
            return out;
        }),
    };
}
