// SystemVerilog and Coding Rules Syntax Validator
const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..', '..');

console.log('======================================================================');
console.log('       SMBUS UVM VERIFICATION ENVIRONMENT - SYNTAX & RULE CHECK       ');
console.log('======================================================================');

let totalFilesChecked = 0;
let totalErrors = 0;
let totalWarnings = 0;

function getAllFiles(dir, exts, fileList = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            if (file !== 'log' && file !== 'work' && file !== '.git') {
                getAllFiles(fullPath, exts, fileList);
            }
        } else {
            const ext = path.extname(file);
            if (exts.includes(ext) || ext === '.pkg' || ext === '.f') {
                fileList.push(fullPath);
            }
        }
    }
    return fileList;
}

function stripCommentsAndStrings(code) {
    return code
        .replace(/\/\*[\s\S]*?\*\//g, ' ')
        .replace(/\/\/.*/g, ' ')
        .replace(/"(?:\\.|[^"\\])*"/g, '""');
}

const svFiles = getAllFiles(projectRoot, ['.sv', '.pkg', '.f']);

console.log(`Found ${svFiles.length} project files to validate.\n`);

svFiles.forEach(filePath => {
    const relPath = path.relative(projectRoot, filePath);
    const content = fs.readFileSync(filePath, 'utf-8');
    totalFilesChecked++;

    if (filePath.endsWith('.f')) {
        const lines = content.split('\n');
        const dir = path.dirname(filePath);
        lines.forEach(line => {
            const trimmed = line.trim();
            if (trimmed && !trimmed.startsWith('//') && !trimmed.startsWith('+incdir+')) {
                const target = path.resolve(dir, trimmed);
                if (!fs.existsSync(target)) {
                    console.error(`[ERROR] File in ${relPath} does not exist: ${trimmed}`);
                    totalErrors++;
                }
            }
        });
        console.log(`[PASS] ${relPath.padEnd(48)} - File list valid`);
        return;
    }

    const stripped = stripCommentsAndStrings(content);
    let fileErrs = 0;

    const checkPairs = [
        ['\\bclass\\s+\\w+', '\\bendclass\\b'],
        ['\\bpackage\\s+\\w+', '\\bendpackage\\b'],
        ['\\binterface\\s+\\w+', '\\bendinterface\\b'],
        ['\\bmodule\\s+\\w+', '\\bendmodule\\b'],
        ['\\bbegin\\b', '\\bend\\b'],
        ['\\bcase\\s*\\(', '\\bendcase\\b'],
        ['`ifn?def\\b', '`endif\\b']
    ];

    checkPairs.forEach(([startPat, endPat]) => {
        const startRegex = new RegExp(startPat, 'g');
        const endRegex = new RegExp(endPat, 'g');
        const startCount = (stripped.match(startRegex) || []).length;
        const endCount = (stripped.match(endRegex) || []).length;
        if (startCount !== endCount) {
            console.error(`[ERROR] Mismatched pattern ${startPat} (${startCount}) and ${endPat} (${endCount}) in ${relPath}`);
            totalErrors++;
            fileErrs++;
        }
    });

    // Check function/endfunction and task/endtask excluding extern prototypes
    const nonExternFuncCount = (stripped.match(/(?<!\bextern\s+)\bfunction\b/g) || []).length;
    const endFuncCount = (stripped.match(/\bendfunction\b/g) || []).length;
    if (nonExternFuncCount !== endFuncCount) {
        console.error(`[ERROR] Mismatched function (${nonExternFuncCount}) and endfunction (${endFuncCount}) in ${relPath}`);
        totalErrors++;
        fileErrs++;
    }

    const nonExternTaskCount = (stripped.match(/(?<!\bextern\s+)\btask\b/g) || []).length;
    const endTaskCount = (stripped.match(/\bendtask\b/g) || []).length;
    if (nonExternTaskCount !== endTaskCount) {
        console.error(`[ERROR] Mismatched task (${nonExternTaskCount}) and endtask (${endTaskCount}) in ${relPath}`);
        totalErrors++;
        fileErrs++;
    }

    if (fileErrs === 0) {
        console.log(`[PASS] ${relPath.padEnd(48)} - Clean`);
    }
});

console.log('\n======================================================================');
console.log(`Validation Summary: ${totalFilesChecked} files checked.`);
console.log(`Errors   : ${totalErrors}`);
console.log(`Warnings : ${totalWarnings}`);
console.log(totalErrors === 0 ? 'STATUS   : ALL FILES VALID & COMPLIANT' : 'STATUS   : FAILED');
console.log('======================================================================');

process.exit(totalErrors === 0 ? 0 : 1);
