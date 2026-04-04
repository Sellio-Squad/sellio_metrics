let _globalKvWriteCount: number = 0;
let _kvWriteResetDay: string = "";

function todayKey(): string {
    return new Date().toISOString().slice(0, 10); // "YYYY-MM-DD"
}

export function trackKvWrite() {
    const today = todayKey();
    if (_kvWriteResetDay !== today) {
        _globalKvWriteCount = 0;
        _kvWriteResetDay = today;
    }
    _globalKvWriteCount++;
}

export function getKvWriteCountForToday(): number {
    const today = todayKey();
    return _kvWriteResetDay === today ? _globalKvWriteCount : 0;
}
