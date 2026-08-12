.pragma library

function formatTemp(temp, useFahrenheit, showUnit, LocationService) {
    const v = Math.round(useFahrenheit ? LocationService.celsiusToFahrenheit(temp) : temp);
    return v + (showUnit ? (useFahrenheit ? "°F" : "°C") : "");
}

function getTooltipRows(weather, tooltipOption, useFahrenheit, use12h, tr, LocationService, I18n) {
    if (!weather) return [];
    const rows = [];
    const fmt = use12h ? "hh:mm AP" : "HH:mm";

    const f = (t) => formatTemp(t, useFahrenheit, true, LocationService);

    if (tooltipOption === "everything") {
        rows.push([tr("tooltips.current"), f(weather.current_weather.temperature)]);
    }
    if (tooltipOption === "everything" || tooltipOption === "highlow") {
        rows.push([tr("tooltips.high"), f(weather.daily.temperature_2m_max[0])]);
        rows.push([tr("tooltips.low"), f(weather.daily.temperature_2m_min[0])]);
    }
    if (tooltipOption === "everything" || tooltipOption === "sunrise") {
        rows.push([tr("tooltips.sunrise"), I18n.locale.toString(new Date(weather.daily.sunrise[0]), fmt)]);
        rows.push([tr("tooltips.sunset"), I18n.locale.toString(new Date(weather.daily.sunset[0]), fmt)]);
    }
    return rows;
}
