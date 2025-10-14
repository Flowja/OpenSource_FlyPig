// 定义常量
const PI = 3.1415926535897932384626;
const A = 6378245.0;
const EE = 0.00669342162296594323;

/**
 * WGS-84 转 GCJ-02
 * @param {number} lng - 经度
 * @param {number} lat - 纬度
 * @returns {number[]} [经度, 纬度]
 */
function wgs84ToGcj02(lng, lat) {
    if (outOfChina(lng, lat)) {
        return {
            longitude: lng,
            latitude: lat
        };
    }

    let dlat = transformLat(lng - 105.0, lat - 35.0);
    let dlng = transformLng(lng - 105.0, lat - 35.0);

    const radlat = lat / 180.0 * PI;
    let magic = Math.sin(radlat);
    magic = 1 - EE * magic * magic;

    const sqrtmagic = Math.sqrt(magic);
    dlat = (dlat * 180.0) / ((A * (1 - EE)) / (magic * sqrtmagic) * PI);
    dlng = (dlng * 180.0) / (A / sqrtmagic * Math.cos(radlat) * PI);

    const mglat = lat + dlat;
    const mglng = lng + dlng;

    return {
        longitude: mglng,
        latitude: mglat
    };
}

/**
 * 判断坐标是否在中国境外
 */
function outOfChina(lng, lat) {
    return (lng < 72.004 || lng > 137.8347) || (lat < 0.8293 || lat > 55.8271);
}

/**
 * 纬度转换
 */
function transformLat(lng, lat) {
    let ret = -100.0 + 2.0 * lng + 3.0 * lat + 0.2 * lat * lat + 0.1 * lng * lat + 0.2 * Math.sqrt(Math.abs(lng));
    ret += (20.0 * Math.sin(6.0 * lng * PI) + 20.0 * Math.sin(2.0 * lng * PI)) * 2.0 / 3.0;
    ret += (20.0 * Math.sin(lat * PI) + 40.0 * Math.sin(lat / 3.0 * PI)) * 2.0 / 3.0;
    ret += (160.0 * Math.sin(lat / 12.0 * PI) + 320 * Math.sin(lat * PI / 30.0)) * 2.0 / 3.0;
    return ret;
}

/**
 * 经度转换
 */
function transformLng(lng, lat) {
    let ret = 300.0 + lng + 2.0 * lat + 0.1 * lng * lng + 0.1 * lng * lat + 0.1 * Math.sqrt(Math.abs(lng));
    ret += (20.0 * Math.sin(6.0 * lng * PI) + 20.0 * Math.sin(2.0 * lng * PI)) * 2.0 / 3.0;
    ret += (20.0 * Math.sin(lng * PI) + 40.0 * Math.sin(lng / 3.0 * PI)) * 2.0 / 3.0;
    ret += (150.0 * Math.sin(lng / 12.0 * PI) + 300.0 * Math.sin(lng / 30.0 * PI)) * 2.0 / 3.0;
    return ret;
}

// 导出函数供其他文件使用
module.exports = {
    wgs84ToGcj02: wgs84ToGcj02
};