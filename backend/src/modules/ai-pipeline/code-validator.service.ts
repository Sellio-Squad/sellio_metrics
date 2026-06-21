/**
 * Sellio Metrics — Structural Code Validator
 *
 * Pre-GitHub CI validation that runs INSIDE Cloudflare Workers.
 * Validates generated code BEFORE committing to prevent bad code from reaching GitHub.
 *
 * Checks performed:
 *   1. Import Resolution — Verify that all imported modules exist in the file tree or dependencies
 *   2. Dependency Verification — Check that referenced packages exist in pubspec.yaml / package.json
 *   3. Basic Syntax Validation — Bracket matching, string termination, structural integrity
 *   4. File Path Validation — Modified files exist in repo, new files don't conflict
 *   5. Cross-File Consistency — Verify exports/imports align between modified files
 */

import type { Logger } from "../../core/logger";
import type { RepoContext, CodeChange, ImplementationPlan } from "./ai-pipeline.types";

export interface ValidationError {
    file: string;
    line?: number;
    type: "missing_import" | "syntax_error" | "missing_dependency" | "file_not_found" | "bracket_mismatch" | "cross_ref_error";
    message: string;
    severity: "error" | "warning";
}

export interface ValidationResult {
    success: boolean;
    errors: ValidationError[];
    warnings: ValidationError[];
    summary: string;
}

export class CodeValidatorService {
    private readonly logger: Logger;

    constructor({ logger }: { logger: Logger }) {
        this.logger = logger.child({ module: "code-validator" });
    }

    /**
     * Run all structural validations on generated code changes.
     * This is the Cloudflare-side pre-CI check.
     */
    async validate(
        changes: CodeChange[],
        context: RepoContext,
        plan: ImplementationPlan
    ): Promise<ValidationResult> {
        this.logger.info({ fileCount: changes.length }, "Running pre-GitHub structural validation");

        const allErrors: ValidationError[] = [];
        const allWarnings: ValidationError[] = [];

        for (const change of changes) {
            // 1. File path validation
            if (change.action === "modify") {
                const filePathErrors = this.validateFilePath(change, context);
                allErrors.push(...filePathErrors.filter(e => e.severity === "error"));
                allWarnings.push(...filePathErrors.filter(e => e.severity === "warning"));
            }

            // 2. Syntax validation (bracket matching, etc.)
            const syntaxErrors = this.validateSyntax(change);
            allErrors.push(...syntaxErrors.filter(e => e.severity === "error"));
            allWarnings.push(...syntaxErrors.filter(e => e.severity === "warning"));

            // 3. Import resolution
            const importErrors = this.validateImports(change, changes, context);
            allErrors.push(...importErrors.filter(e => e.severity === "error"));
            allWarnings.push(...importErrors.filter(e => e.severity === "warning"));

            // 4. Dependency verification
            const depErrors = this.validateDependencies(change, context);
            allErrors.push(...depErrors.filter(e => e.severity === "error"));
            allWarnings.push(...depErrors.filter(e => e.severity === "warning"));
        }

        // 5. Cross-file consistency
        const crossRefErrors = this.validateCrossFileRefs(changes, context);
        allErrors.push(...crossRefErrors.filter(e => e.severity === "error"));
        allWarnings.push(...crossRefErrors.filter(e => e.severity === "warning"));

        const success = allErrors.length === 0;
        const summary = success
            ? `✅ All ${changes.length} files passed structural validation (${allWarnings.length} warnings)`
            : `❌ Structural validation failed: ${allErrors.length} errors, ${allWarnings.length} warnings`;

        this.logger.info({ success, errorCount: allErrors.length, warningCount: allWarnings.length }, summary);

        return { success, errors: allErrors, warnings: allWarnings, summary };
    }

    // ─── File Path Validation ─────────────────────────────────

    private validateFilePath(change: CodeChange, context: RepoContext): ValidationError[] {
        const errors: ValidationError[] = [];

        if (change.action === "modify") {
            const exists = context.fileTree.some(f => f === change.path);
            if (!exists) {
                errors.push({
                    file: change.path,
                    type: "file_not_found",
                    message: `File "${change.path}" is marked as 'modify' but does not exist in the repository file tree. Did you mean to 'create' it?`,
                    severity: "error",
                });
            }
        }

        return errors;
    }

    // ─── Syntax Validation ────────────────────────────────────

    private validateSyntax(change: CodeChange): ValidationError[] {
        const errors: ValidationError[] = [];
        const content = change.content;
        const ext = change.path.split(".").pop()?.toLowerCase() || "";

        // Skip non-code files
        if (["json", "yaml", "yml", "md", "txt", "toml"].includes(ext)) {
            return this.validateStructuredFile(change, ext);
        }

        // Bracket matching for code files
        const bracketErrors = this.checkBracketMatching(change.path, content);
        errors.push(...bracketErrors);

        // Check for unclosed strings (basic check)
        const stringErrors = this.checkUnclosedStrings(change.path, content, ext);
        errors.push(...stringErrors);

        // Check for empty file content
        if (content.trim().length === 0) {
            errors.push({
                file: change.path,
                type: "syntax_error",
                message: "File has empty content. This is likely an error in code generation.",
                severity: "error",
            });
        }

        return errors;
    }

    private validateStructuredFile(change: CodeChange, ext: string): ValidationError[] {
        const errors: ValidationError[] = [];

        if (ext === "json") {
            try {
                JSON.parse(change.content);
            } catch (e: any) {
                errors.push({
                    file: change.path,
                    type: "syntax_error",
                    message: `Invalid JSON: ${e.message}`,
                    severity: "error",
                });
            }
        }

        return errors;
    }

    private checkBracketMatching(filePath: string, content: string): ValidationError[] {
        const errors: ValidationError[] = [];
        const stack: { char: string; line: number }[] = [];
        const lines = content.split("\n");
        const pairs: Record<string, string> = { "(": ")", "[": "]", "{": "}" };
        const closers = new Set([")", "]", "}"]);

        let inString = false;
        let stringChar = "";
        let inLineComment = false;
        let inBlockComment = false;

        for (let lineIdx = 0; lineIdx < lines.length; lineIdx++) {
            const line = lines[lineIdx];
            inLineComment = false;

            for (let i = 0; i < line.length; i++) {
                const ch = line[i];
                const next = i + 1 < line.length ? line[i + 1] : "";

                // Handle block comments
                if (inBlockComment) {
                    if (ch === "*" && next === "/") {
                        inBlockComment = false;
                        i++; // skip /
                    }
                    continue;
                }

                // Handle line comments
                if (inLineComment) continue;

                // Start block comment
                if (ch === "/" && next === "*") {
                    inBlockComment = true;
                    i++;
                    continue;
                }

                // Start line comment
                if (ch === "/" && next === "/") {
                    inLineComment = true;
                    continue;
                }

                // Handle strings
                if (inString) {
                    if (ch === "\\" ) {
                        i++; // skip escaped char
                        continue;
                    }
                    if (ch === stringChar) {
                        inString = false;
                    }
                    continue;
                }

                // Start string
                if (ch === '"' || ch === "'" || ch === "`") {
                    inString = true;
                    stringChar = ch;
                    continue;
                }

                // Track brackets
                if (pairs[ch]) {
                    stack.push({ char: ch, line: lineIdx + 1 });
                } else if (closers.has(ch)) {
                    if (stack.length === 0) {
                        errors.push({
                            file: filePath,
                            line: lineIdx + 1,
                            type: "bracket_mismatch",
                            message: `Unexpected closing bracket '${ch}' at line ${lineIdx + 1} with no matching opener`,
                            severity: "error",
                        });
                    } else {
                        const top = stack.pop()!;
                        const expected = pairs[top.char];
                        if (expected !== ch) {
                            errors.push({
                                file: filePath,
                                line: lineIdx + 1,
                                type: "bracket_mismatch",
                                message: `Bracket mismatch: expected '${expected}' (opened at line ${top.line}) but found '${ch}' at line ${lineIdx + 1}`,
                                severity: "error",
                            });
                        }
                    }
                }
            }
        }

        // Check for unclosed brackets
        for (const unclosed of stack) {
            errors.push({
                file: filePath,
                line: unclosed.line,
                type: "bracket_mismatch",
                message: `Unclosed bracket '${unclosed.char}' opened at line ${unclosed.line}`,
                severity: "error",
            });
        }

        return errors;
    }

    private checkUnclosedStrings(filePath: string, content: string, ext: string): ValidationError[] {
        // Only for single-line string checking (basic). Multi-line strings are tricky.
        // Skip template literals and multi-line strings for now.
        const errors: ValidationError[] = [];
        const lines = content.split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            // Skip comments
            if (line.startsWith("//") || line.startsWith("*") || line.startsWith("/*")) continue;

            // Count unescaped quotes (very basic check)
            const singleQuotes = (line.match(/(?<!\\)'/g) || []).length;
            const doubleQuotes = (line.match(/(?<!\\)"/g) || []).length;

            // If line has an odd number of both types of quotes, it might have unclosed strings
            // But this is too noisy for real code (template literals, multi-line, etc.)
            // Only flag obvious cases: a line that starts with an assignment and has odd quotes
            if (ext === "dart" && singleQuotes % 2 !== 0 && !line.includes("'''") && !line.includes('"""')) {
                // Check if it's not a multi-line string or raw string
                if (!line.endsWith(",") && !line.endsWith("(") && !line.endsWith("+")) {
                    errors.push({
                        file: filePath,
                        line: i + 1,
                        type: "syntax_error",
                        message: `Possible unclosed string at line ${i + 1} (odd number of single quotes)`,
                        severity: "warning",
                    });
                }
            }
        }

        return errors;
    }

    // ─── Import Resolution ────────────────────────────────────

    private validateImports(change: CodeChange, allChanges: CodeChange[], context: RepoContext): ValidationError[] {
        const errors: ValidationError[] = [];
        const ext = change.path.split(".").pop()?.toLowerCase() || "";
        const content = change.content;

        if (ext === "ts" || ext === "tsx" || ext === "js" || ext === "jsx") {
            this.validateTypeScriptImports(change.path, content, allChanges, context, errors);
        } else if (ext === "dart") {
            this.validateDartImports(change.path, content, allChanges, context, errors);
        }

        return errors;
    }

    private validateTypeScriptImports(
        filePath: string,
        content: string,
        allChanges: CodeChange[],
        context: RepoContext,
        errors: ValidationError[]
    ): void {
        const importRegex = /import\s+(?:(?:type\s+)?(?:\{[^}]*\}|\*\s+as\s+\w+|\w+)\s+from\s+)?['"](\.\.?\/[^'"]+)['"]/g;
        const lines = content.split("\n");
        let match;

        while ((match = importRegex.exec(content)) !== null) {
            const importPath = match[1];
            
            // Only validate relative imports (starting with . or ..)
            if (!importPath.startsWith(".")) continue;

            // Resolve import path relative to the file
            const resolvedPath = this.resolveRelativeImport(filePath, importPath);

            // Check if the imported file exists in:
            // 1. Repository file tree
            // 2. Other generated files in this changeset
            const possiblePaths = [
                resolvedPath,
                resolvedPath + ".ts",
                resolvedPath + ".tsx",
                resolvedPath + ".js",
                resolvedPath + ".jsx",
                resolvedPath + "/index.ts",
                resolvedPath + "/index.js",
            ];

            const existsInTree = possiblePaths.some(p => context.fileTree.includes(p));
            const existsInChanges = possiblePaths.some(p => allChanges.some(c => c.path === p));

            if (!existsInTree && !existsInChanges) {
                const line = this.findLineNumber(content, match[0]);
                errors.push({
                    file: filePath,
                    line,
                    type: "missing_import",
                    message: `Import "${importPath}" (resolved to "${resolvedPath}") not found in repository or generated files`,
                    severity: "error",
                });
            }
        }
    }

    private validateDartImports(
        filePath: string,
        content: string,
        allChanges: CodeChange[],
        context: RepoContext,
        errors: ValidationError[]
    ): void {
        const importRegex = /import\s+['"]([^'"]+)['"]/g;
        let match;

        while ((match = importRegex.exec(content)) !== null) {
            const importPath = match[1];

            // Skip dart: and package: imports (handled by dependency check)
            if (importPath.startsWith("dart:") || importPath.startsWith("package:")) continue;

            // ── Skip known auto-generated files ──────────────────────────────────
            // These files are produced at build time (flutter gen-l10n, build_runner,
            // freezed, auto_route, mockito, etc.) and will never appear in the source
            // file tree. Flagging them as missing imports is a false positive.
            if (this.isDartGeneratedFile(importPath)) continue;

            // Resolve import path relative to the file.
            // Dart allows both explicit relative (./foo.dart) and implicit relative
            // (core/foo.dart meaning relative to the current file's directory).
            const resolvedPath = this.resolveRelativeImport(filePath, importPath);

            const existsInTree = context.fileTree.includes(resolvedPath);
            const existsInChanges = allChanges.some(c => c.path === resolvedPath);

            if (!existsInTree && !existsInChanges) {
                const line = this.findLineNumber(content, match[0]);
                errors.push({
                    file: filePath,
                    line,
                    type: "missing_import",
                    message: `Relative import "${importPath}" (resolved to "${resolvedPath}") not found in repository or generated files`,
                    severity: "error",
                });
            }
        }
    }

    /**
     * Returns true for files that are produced by Flutter/Dart build tooling
     * and will not exist in the source repository tree.
     *
     * Covers:
     *   - Flutter l10n:       app_localizations.dart, app_localizations_en.dart, ...
     *   - build_runner:       *.g.dart  (json_serializable, hive, etc.)
     *   - freezed:            *.freezed.dart
     *   - auto_route:         *.gr.dart
     *   - mockito:            *.mocks.dart
     *   - injectable:         *.config.dart  (when generated)
     *   - generated dirs:     .dart_tool/, build/generated/
     */
    private isDartGeneratedFile(importPath: string): boolean {
        const filename = importPath.split("/").pop() || "";

        // Flutter l10n files generated by `flutter gen-l10n`
        if (filename === "app_localizations.dart") return true;
        if (filename.startsWith("app_localizations_") && filename.endsWith(".dart")) return true;

        // build_runner generated suffixes
        if (filename.endsWith(".g.dart")) return true;         // json_serializable, hive, etc.
        if (filename.endsWith(".freezed.dart")) return true;  // freezed
        if (filename.endsWith(".mocks.dart")) return true;    // mockito
        if (filename.endsWith(".gr.dart")) return true;       // auto_route
        if (filename.endsWith(".gen.dart")) return true;      // misc generators

        // Generated output directories
        if (importPath.includes(".dart_tool/")) return true;
        if (importPath.includes("build/generated/")) return true;

        return false;
    }

    // ─── Dependency Verification ──────────────────────────────

    private validateDependencies(change: CodeChange, context: RepoContext): ValidationError[] {
        const errors: ValidationError[] = [];
        const ext = change.path.split(".").pop()?.toLowerCase() || "";
        const deps = context.dependencies || {};

        if (ext === "ts" || ext === "tsx" || ext === "js" || ext === "jsx") {
            this.validateNpmDependencies(change.path, change.content, deps, errors);
        } else if (ext === "dart") {
            this.validateDartDependencies(change.path, change.content, deps, errors);
        }

        return errors;
    }

    private validateNpmDependencies(
        filePath: string,
        content: string,
        deps: Record<string, string>,
        errors: ValidationError[]
    ): void {
        // Match imports of npm packages (not relative paths)
        const importRegex = /import\s+(?:(?:type\s+)?(?:\{[^}]*\}|\*\s+as\s+\w+|\w+)\s+from\s+)?['"]([^.\/][^'"]*)['"]/g;
        let match;

        // Well-known Node.js built-in modules to skip
        const builtins = new Set([
            "fs", "path", "os", "crypto", "http", "https", "stream", "url",
            "querystring", "util", "events", "buffer", "child_process", "net",
            "node:fs", "node:path", "node:os", "node:crypto", "node:http",
            "node:https", "node:stream", "node:url", "node:util", "node:events",
            "node:buffer", "node:child_process", "node:net",
        ]);

        while ((match = importRegex.exec(content)) !== null) {
            const pkg = match[1];
            if (!pkg) continue;

            // Skip built-ins
            if (builtins.has(pkg)) continue;

            // Get the root package name (e.g., "@cloudflare/workers-types" → "@cloudflare/workers-types")
            let rootPkg = pkg;
            if (pkg.startsWith("@")) {
                const parts = pkg.split("/");
                rootPkg = parts.length >= 2 ? `${parts[0]}/${parts[1]}` : pkg;
            } else {
                rootPkg = pkg.split("/")[0];
            }

            // Check if package is in dependencies
            if (!deps[rootPkg]) {
                const line = this.findLineNumber(content, match[0]);
                errors.push({
                    file: filePath,
                    line,
                    type: "missing_dependency",
                    message: `Package "${rootPkg}" is imported but not found in package.json dependencies`,
                    severity: "warning", // Warning, not error — could be a type-only import or workspace package
                });
            }
        }
    }

    private validateDartDependencies(
        filePath: string,
        content: string,
        deps: Record<string, string>,
        errors: ValidationError[]
    ): void {
        const importRegex = /import\s+['"]package:([^/]+)\//g;
        let match;

        while ((match = importRegex.exec(content)) !== null) {
            const pkg = match[1];

            // Skip the project's own package and flutter/dart built-ins
            if (deps[pkg] || pkg === "flutter" || pkg === "flutter_test" || pkg === "flutter_localizations") continue;

            // Check against known dependencies
            if (!deps[pkg]) {
                const line = this.findLineNumber(content, match[0]);
                errors.push({
                    file: filePath,
                    line,
                    type: "missing_dependency",
                    message: `Dart package "${pkg}" is imported but not found in pubspec.yaml dependencies`,
                    severity: "warning",
                });
            }
        }
    }

    // ─── Cross-File Consistency ───────────────────────────────

    private validateCrossFileRefs(changes: CodeChange[], context: RepoContext): ValidationError[] {
        const errors: ValidationError[] = [];

        // Build a set of all exports from modified files
        const exportedSymbols = new Map<string, Set<string>>();
        for (const change of changes) {
            const ext = change.path.split(".").pop()?.toLowerCase() || "";
            if (ext === "ts" || ext === "tsx") {
                const exports = this.extractExports(change.content);
                exportedSymbols.set(change.path, exports);
            }
        }

        // Check that named imports from generated files match their exports
        for (const change of changes) {
            const ext = change.path.split(".").pop()?.toLowerCase() || "";
            if (ext !== "ts" && ext !== "tsx") continue;

            const namedImports = this.extractNamedImports(change.path, change.content);
            for (const { fromPath, names, line } of namedImports) {
                // Resolve the import path
                const resolved = this.resolveRelativeImport(change.path, fromPath);

                // Find possible matches
                const possiblePaths = [
                    resolved,
                    resolved + ".ts",
                    resolved + ".tsx",
                    resolved + "/index.ts",
                ];

                for (const p of possiblePaths) {
                    const exports = exportedSymbols.get(p);
                    if (exports) {
                        for (const name of names) {
                            if (!exports.has(name) && !exports.has("*")) {
                                errors.push({
                                    file: change.path,
                                    line,
                                    type: "cross_ref_error",
                                    message: `Symbol "${name}" is imported from "${fromPath}" but not exported by "${p}"`,
                                    severity: "warning",
                                });
                            }
                        }
                        break;
                    }
                }
            }
        }

        return errors;
    }

    // ─── Utility Helpers ──────────────────────────────────────

    private resolveRelativeImport(currentFile: string, importPath: string): string {
        const currentDir = currentFile.split("/").slice(0, -1).join("/");
        const parts = importPath.split("/");
        const dirParts = currentDir.split("/");

        for (const part of parts) {
            if (part === ".") {
                // Stay in current dir
            } else if (part === "..") {
                dirParts.pop();
            } else {
                dirParts.push(part);
            }
        }

        return dirParts.join("/");
    }

    private findLineNumber(content: string, searchStr: string): number {
        const idx = content.indexOf(searchStr);
        if (idx === -1) return 0;
        return content.substring(0, idx).split("\n").length;
    }

    private extractExports(content: string): Set<string> {
        const exports = new Set<string>();

        // export class/function/const/interface/type/enum
        const declRegex = /export\s+(?:default\s+)?(?:class|function|const|let|var|interface|type|enum|abstract\s+class)\s+(\w+)/g;
        let match;
        while ((match = declRegex.exec(content)) !== null) {
            exports.add(match[1]);
        }

        // export { A, B, C }
        const namedExportRegex = /export\s+\{([^}]+)\}/g;
        while ((match = namedExportRegex.exec(content)) !== null) {
            const names = match[1].split(",").map(n => n.trim().split(/\s+as\s+/).pop()?.trim() || "");
            for (const name of names) {
                if (name) exports.add(name);
            }
        }

        // export * (wildcard re-export)
        if (/export\s+\*/.test(content)) {
            exports.add("*");
        }

        return exports;
    }

    private extractNamedImports(filePath: string, content: string): { fromPath: string; names: string[]; line: number }[] {
        const results: { fromPath: string; names: string[]; line: number }[] = [];
        const regex = /import\s+(?:type\s+)?\{([^}]+)\}\s+from\s+['"](\.\.?\/[^'"]+)['"]/g;
        let match;

        while ((match = regex.exec(content)) !== null) {
            const names = match[1].split(",")
                .map(n => n.trim().split(/\s+as\s+/)[0].trim())
                .filter(n => n.length > 0);
            const fromPath = match[2];
            const line = this.findLineNumber(content, match[0]);
            results.push({ fromPath, names, line });
        }

        return results;
    }
}
