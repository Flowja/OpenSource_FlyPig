-- main.lua
-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "fly_pig"
VERSION = "1.0.0"
local sys = require("sys")
local aliyun = require("aliyun")
local exgnss = require("exgnss")
-- local pin = require("pin")

-- local payloadconst =
-- [[{"id":123456,"version":"1.0","GeoLocation":{"Latitude":31.123456,"Longitude":121.123456,"Speed":0.0,"Course":0.0,"Altitude":10.0,"CoordinateSystem":1}}]]
-- local need_report_location = false
-- 配置阿里云连接参数
local aliyunConfig = {
    ProductKey = "替换",
    DeviceName = "替换",
    DeviceSecret = "替换",
    RegionId = "cn-shanghai", -- 根据实际情况修改
    mqtt_isssl = true
}

-- 初始化阿里云连接
aliyun.setup(aliyunConfig)
AliyunStatusLED = gpio.setup(27, 0, gpio.PULLUP)    --aliyun status led
StatusLED = gpio.setup(26, 0, gpio.PULLUP)          --status led
Ws2812port = gpio.setup(19, 0, gpio.PULLUP, nil, 4) --ws2812 port
local ws2812bpin = 19

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)                     --初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000) --3s喂一次狗
end
--[[

注意,使用前先看本注释每一句话！！！！！！！
注意,使用前先看本注释每一句话！！！！！！！
注意,使用前先看本注释每一句话！！！！！！！

说明：ws2812在Cat.1模组上挂载，如果在网络环境下使用会有干扰，
因为网络优先级是最高的，会导致时序干扰造成某个灯珠颜色异常，效果不是很好，
不推荐使用。如果认为影响较大，建议通过外挂MCU实现。

注意,使用前先看本注释！！！！！！！！！！！
注意,使用前先看本注释！！！！！！！！！！！
注意,使用前先看本注释！！！！！！！！！！！

]]
--可选pwm,gpio,spi方式驱动,API详情查看wiki https://wiki.luatos.com/api/sensor.html

-- mode pin/pwm_id/spi_id T0H T0L T1H T1L
local function ws2812_conf()
    local rtos_bsp = rtos.bsp()
    if rtos_bsp == "AIR101" then
        return "pin", pin.PA7, 0, 20, 20, 0  --此为pin方式直驱,注意air101主频设置240
    elseif rtos_bsp == "AIR103" then
        return "pin", pin.PA7, 0, 20, 20, 0  --此为pin方式直驱,注意air103主频设置240
    elseif rtos_bsp == "AIR105" then
        return "pin", pin.PD13, 0, 10, 10, 0 --此为pin方式直驱
    elseif rtos_bsp == "ESP32C3" then
        return "pin", 2, 0, 10, 10, 0        --此为pin方式直驱
    elseif rtos_bsp == "ESP32S3" then
        return "pin", 2, 0, 10, 10, 0        --此为pin方式直驱
    elseif rtos_bsp == "EC618" then
        return "pin", 24, 10, 0, 10, 0       --此为pin方式直驱 (需要2023.7.25之后编译的固件,否则只能使用spi方式)
    elseif rtos_bsp == "EC718P" then
        return "pin", 29, 12, 25, 50, 30
    else
        log.info("main", "bsp not support")
        return
    end
end

local led_count = 20 -- 根据实际LED数量调整

local buff = zbuff.create({ 1, led_count, 24 }, 0x000000)
local function send_ws2812_data()
    sensor.ws2812b(ws2812bpin, buff)
end
local function led_clear()
    buff:clear(0x000000)
    send_ws2812_data()
end
local function ws2812_init()
    buff:clear(0x000000)
    send_ws2812_data()
end
local hue = 0          -- 色相值，范围0-360
local brightness = 0.2 -- 亮度值，范围0-1
local saturation = 1   -- 饱和度值，范围0-1
local function hsv_to_rgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b

    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    return (r + m) * 255, (g + m) * 255, (b + m) * 255
end
-- 准备渐变色彩数据
local function set_gradient_data(h, s, v)
    local r, g, b = hsv_to_rgb(h, s, v)
    local color = math.floor(b) * 65536 + math.floor(r) * 256 + math.floor(g)
    buff:setFrameBuffer(1, 20, 24, color)
end
local function ws2812_gradient()
    while true do
        set_gradient_data(hue, saturation, brightness)
        send_ws2812_data()
        hue = (hue + 1) % 360 -- 色相递增，实现渐变效果
        -- log.info("color",color)
        sys.wait(50)          -- 每50ms更新一次颜色
    end
end

-- 显示单色
local function show_singlecolor_all(rgb)
    buff:setFrameBuffer(1, 20, 24, rgb)
    while true do
        send_ws2812_data()
        sys.wait(1000) -- 每秒更新一次
    end
end
local function set_led_color(n, rgb)
    if not n or n < 0 or n > led_count then
        log.info("set_led_color", "LED编号超出范围")
        return
    end
    buff:pixel(0, n, rgb)
end

local led_pattern = "single"
local color = 0x010101
local function show_led()
    if led_pattern == "single" then
        show_singlecolor_all(color)
    end
end
-- sys.taskInit(show_single_color,0x000100)
-- sys.taskInit(show_led_color)

-- GNSS配置
local function init_gnss()
    local gnssotps = {
        gnssmode = 1,       -- 1为卫星全定位，2为单北斗
        agps_enable = true, -- 是否使用AGPS
        debug = false,      -- 是否输出调试信息
    }
    -- 设置gnss参数
    exgnss.setup(gnssotps)
    log.info("GNSS初始化完成")
end

-- 获取位置信息并上报到阿里云
local function report_location()
    -- 开启GNSS定位，最长60秒
    exgnss.open(exgnss.TIMERORSUC, {
        tag = "REPORT_LOC",
        val = 60,
        cb = function(tag)
            log.info("GNSS定位回调", tag)
            if exgnss.is_fix() then
                -- 获取定位信息
                local rmc = exgnss.rmc(2) -- 获取格式2的位置信息（DD.DDDDDDD格式）
                if rmc and rmc.valid then
                    log.info("定位成功", rmc.lat, rmc.lng)

                    -- 构造上报数据
                    local payload = string.format(
                        [[{"id":%d,"version":"1.0","GeoLocation":{"Latitude":%.6f,"Longitude":%.6f,"Speed":%.2f,"Course":%.2f,"Altitude":%.2f,"CoordinateSystem":1}}]],
                        os.time(),
                        rmc.lat,
                        rmc.lng,
                        rmc.speed or 0,
                        rmc.course or 0,
                        rmc.altitude or 0
                    )

                    -- 上报到阿里云物联网平台
                    if aliyun.ready() then
                        aliyun.publish(
                            "/**/**/**", --替换
                            1,
                            payload,
                            function(result)
                                if result then
                                    log.info("位置上报成功")
                                else
                                    log.info("位置上报失败")
                                end
                            end
                        )
                    else
                        log.info("阿里云未连接，无法上报位置")
                    end
                else
                    log.info("GNSS定位失败或无效")
                end
            else
                log.info("GNSS未定位成功")
            end
        end
    })
end

local need_report_location = false

local function location_report_task()
    while need_report_location do
        if aliyun.ready() then
            report_location()
        else
            log.info("阿里云未连接，跳过本次位置上报")
        end

        sys.wait(5000)
    end
    -- sys.taskDel("location_report_task")
end


local function buildColorMap(data)
    local map = {}
    if data and data.led and data.led.color then
        for _, item in ipairs(data.led.color) do
            if item.partKey and item.color then
                map[item.partKey] = item.color
            end
        end
    end
    return map
end
local earlefttop_color = 0x0b2a09
local earrighttop_color = 0x0b2a09
local earleftbottom_color = 0x0b2a09
local earrightbottom_color = 0x0b2a09
local earleftmiddle_color = 0x0b2a09
local earrightmiddle_color = 0x0b2a09
local run_animation = false
local frame_time = 200
local init_led_map = { 1, 2, 3, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19 }
local function get_current_frames()
    local default_color = 0x0b2a09
    earlefttop_color = earlefttop_color == 0 and default_color or earlefttop_color
    earrighttop_color = earrighttop_color == 0 and default_color or earrighttop_color
    earleftbottom_color = earleftbottom_color == 0 and default_color or earleftbottom_color
    earrightbottom_color = earrightbottom_color == 0 and default_color or earrightbottom_color
    earleftmiddle_color = earleftmiddle_color == 0 and default_color or earleftmiddle_color
    earrightmiddle_color = earrightmiddle_color == 0 and default_color or earrightmiddle_color
    return {
        {
            { 0, earlefttop_color }, { 6, 0x000000 }, { 7, 0x000000 },
            { 4, earrighttop_color }, { 5, 0x000000 }, { 11, 0x000000 }
        },
        {
            { 0, 0x000000 }, { 6, earleftmiddle_color }, { 7, 0x000000 },
            { 4, 0x000000 }, { 5, earrightmiddle_color }, { 11, 0x000000 }
        },
        {
            { 0, 0x000000 }, { 6, 0x000000 }, { 7, earleftbottom_color },
            { 4, 0x000000 }, { 5, 0x000000 }, { 11, earrightbottom_color }
        },
        {
            { 0, 0x000000 }, { 6, earleftmiddle_color }, { 7, 0x000000 },
            { 4, 0x000000 }, { 5, earrightmiddle_color }, { 11, 0x000000 }
        }
    }
end
local function flap_wing()
    led_clear()

    for i = 1, #init_led_map do
        if init_led_map[i] == 1 or init_led_map[i] == 3 or init_led_map[i] == 9 then
            set_led_color(init_led_map[i], 0x051609)
        else
            set_led_color(init_led_map[i], 0x0b2a09)
        end
    end
    local frame_index = 1
    while run_animation do
        log.info("flap_wing", "动画运行中, 帧:", frame_index, "颜色:", earlefttop_color)
        local animation_frames = get_current_frames()

        for _, led_setting in ipairs(animation_frames[frame_index]) do
            set_led_color(led_setting[1], led_setting[2])
        end

        send_ws2812_data()
        sys.wait(frame_time)

        frame_index = frame_index % #animation_frames + 1
    end

    log.info("flap_wing", "动画结束")
end

aliyun.on("connect", function(result)
    if result then
        log.info("阿里云连接成功")
        AliyunStatusLED(1)

        aliyun.subscribe("/**/**/**", 1) --替换


        -- sys.taskInit(location_report_task)
    else
        log.info("阿里云连接失败")
        AliyunStatusLED(0)
    end
end)
local low_power_mode = false
local is_sequence_show_led = false
local showing_time = false
local showing_battery = false
local function low_power()
    log.info("开始配置低功耗")
    is_sequence_show_led = false
    run_animation = false
    showing_time = false
    showing_battery = false

    StatusLED(0)
    AliyunStatusLED(0)
    buff:setFrameBuffer(1, 20, 24, 0x000000)
    send_ws2812_data()

    pm.power(pm.WORK_MODE, 1)
    low_power_mode = true
end
local function ntp_time_sync()
    -- 等待联网
    sys.waitUntil("IP_READY")
    sys.wait(1000)
    -- 对于Cat.1模块, 移动/电信卡, 通常会下发基站时间,  那么sntp就不是必要的, 而联通卡通常不会下发, 就需要sntp了
    -- 对应ESP32系列模块, 固件默认也会执行sntp, 所以手动调用sntp也是可选的
    -- sntp内置了几个常用的ntp服务器, 也支持自选服务器
    while 1 do
        -- 使用内置的ntp服务器地址, 包括阿里ntp
        log.info("开始执行SNTP")
        socket.sntp()
        -- 自定义ntp地址
        -- socket.sntp("ntp.aliyun.com")
        -- socket.sntp({"baidu.com", "abc.com", "ntp.air32.cn"})
        -- 通常只需要几百毫秒就能成功
        local ret = sys.waitUntil("NTP_UPDATE", 5000)
        if ret then
            -- 以下是获取/打印时间的演示,注意时区问题
            log.info("sntp", "时间同步成功", "本地时间", os.date())
            -- 正常使用, 一小时一次, 已经足够了, 甚至1天一次也可以
            sys.wait(86400000) -- 24小时后再次同步
        else
            log.info("sntp", "时间同步失败")
            sys.wait(60000) -- 1分钟后重试
        end
    end
end


local led_map = { 2, 4, 5, 11, 12, 19, 17, 15, 14, 7, 6, 0 }
local function show_time()
    while showing_time do
        local timetable = os.date("*t")
        local hour = timetable.hour
        local minute = timetable.min

        led_clear()
        log.info("show_time", "显示当前时间")
        -- sys.taskInit(ntp_time_sync())



        local hour12 = hour % 12
        set_led_color(led_map[hour12 + 1], 0x000100)


        local min_index = math.floor(minute / 5)
        if minute % 5 == 0 then
            set_led_color(led_map[min_index + 1], 0x000200) --红
        elseif minute % 5 == 1 then
            set_led_color(led_map[min_index + 1], 0x010500) --橙
        elseif minute % 5 == 2 then
            set_led_color(led_map[min_index + 1], 0x020200) --黄
        elseif minute % 5 == 3 then
            set_led_color(led_map[min_index + 1], 0x020000) --绿
        elseif minute % 5 == 4 then
            set_led_color(led_map[min_index + 1], 0x000002) --蓝
        end

        log.info("当前时间：", hour, "时", minute, "分")
        send_ws2812_data()
        sys.wait(60000)
    end
end
local function calculate_battery_level(voltage)
    if voltage >= 4.2 then
        return 100
    elseif voltage >= 3.85 then
        -- 4.2V-3.85V 对应 100%-50%
        return 50 + (voltage - 3.85) / (4.2 - 3.85) * 50
    elseif voltage >= 3.7 then
        -- 3.85V-3.7V 对应 50%-20%
        return 20 + (voltage - 3.7) / (3.85 - 3.7) * 30
    elseif voltage >= 3.6 then
        -- 3.7V-3.6V 对应 20%-10%
        return 10 + (voltage - 3.6) / (3.7 - 3.6) * 10
    elseif voltage >= 3.3 then
        -- 3.6V-3.3V 对应 10%-0%
        return (voltage - 3.3) / (3.6 - 3.3) * 10
    else
        return 0
    end
end

local function show_battery_level(level, led_map)
    local led_count = math.floor(level / 100 * 12 + 0.5) -- 四舍五入

    for i = 1, led_count do
        local color
        if level > 50 then
            color = 0x020000 -- 绿色（高电量）
        elseif level > 20 then
            color = 0x020200 -- 黄色（中等电量）
        else
            color = 0x000200 -- 红色（低电量）
        end
        set_led_color(led_map[i], color)
    end
end

local filtered_battery_voltage = 0
local battery_filter_initialized = false

local function read_battery_voltage()
    adc.open(adc.CH_VBAT)
    local current_voltage = adc.get(adc.CH_VBAT) / 1000
    adc.close(adc.CH_VBAT)

    if not battery_filter_initialized then
        filtered_battery_voltage = current_voltage
        battery_filter_initialized = true
    else
        filtered_battery_voltage = 0.2 * current_voltage + 0.8 * filtered_battery_voltage
    end

    return filtered_battery_voltage
end
local function show_battery()
    while showing_battery do
        local voltage = read_battery_voltage()
        local level = calculate_battery_level(voltage)
        log.info("电池电压:", string.format("%.2fV", voltage), "电量:", string.format("%.1f%%", level))
        led_clear()
        show_battery_level(level, led_map)
        send_ws2812_data()
        sys.wait(60000)
    end
end

local function sequence_show_led()
    while is_sequence_show_led do
        if not run_animation then
            run_animation = true
            sys.taskInit(flap_wing)
        end
        sys.wait(20000)
        run_animation = false
        if not showing_time then
            showing_time = true
            sys.taskInit(show_time)
        end
        sys.wait(20000)
        showing_time = false
        if not showing_battery then
            showing_battery = true
            sys.taskInit(show_battery)
        end
        sys.wait(20000)
        showing_battery = false
    end
end
local function net_wake_up()
    if low_power_mode then
        low_power_mode = false
        pm.power(pm.WORK_MODE, 0)
        StatusLED(1)
        if aliyun.ready() then
            AliyunStatusLED(1)
        end
        log.info("net_wake_up", "通过网络退出低功耗模式")
    end
    sys.timerStart(low_power, 120000)
end
local function keypad_wake_up()
    if low_power_mode then
        low_power_mode = false
        pm.power(pm.WORK_MODE, 0)
        StatusLED(1)
        if aliyun.ready() then
            AliyunStatusLED(1)
        end
        log.info("keypad_wake_up", "通过按键退出低功耗模式")
        is_sequence_show_led = true
        sys.taskInit(sequence_show_led)
    end
    sys.timerStart(low_power, 120000)
end
gpio.setup(gpio.WAKEUP0, function()
    keypad_wake_up()
end, gpio.PULLUP, gpio.FALLING)

aliyun.on("receive", function(topic, payload)
    net_wake_up()

    local iot_msg = json.decode(payload)
    if iot_msg == nil then
        log.info("收到无效的JSON消息")
        return
    end
    local iot_locationReport = iot_msg["locationreport"]
    if iot_locationReport then
        if not need_report_location then
            need_report_location = true
            sys.taskInit(location_report_task)
        end
        sys.timerStart(function() need_report_location = false end, 60000) --持续1分钟执行位置上报
        log.info("收到位置上报指令")
    end

    if iot_msg["led"] ~= nil then
        is_sequence_show_led = false
        local colorMap = buildColorMap(iot_msg)
        local led_config = {}
        if iot_msg["led"]["test"] then
            led_config = {
                { index = 0, class = "cls-5", store = function(color) earlefttop_color = color end },       -- 左耳上
                { index = 1, class = "cls-8" },                                                             -- 左眼
                { index = 2, class = "t-1" },                                                               -- 脸
                { index = 3, class = "cls-9" },                                                             -- 右眼
                { index = 4, class = "cls-7", store = function(color) earrighttop_color = color end },      -- 右耳上
                { index = 5, class = "cls-6", store = function(color) earrightmiddle_color = color end },   -- 右耳中
                { index = 6, class = "cls-11", store = function(color) earleftmiddle_color = color end },   -- 左耳中
                { index = 7, class = "cls-13", store = function(color) earleftbottom_color = color end },   -- 左耳下
                { index = 8, class = "cls-1" },                                                             -- 脸
                { index = 9, class = "cls-10" },                                                            -- 鼻
                { index = 10, class = "cls-1" },                                                            -- 脸
                { index = 11, class = "cls-12", store = function(color) earrightbottom_color = color end }, -- 右耳下
                { index = 12, class = "t-2" },                                                              -- 脸
                { index = 13, class = "cls-1" },                                                            -- 脸
                { index = 14, class = "t-6" },                                                              -- 脸
                { index = 15, class = "t-5" },                                                              -- 身
                { index = 16, class = "cls-3" },                                                            -- 左脚
                { index = 17, class = "t-4" },                                                              -- 身
                { index = 18, class = "cls-4" },                                                            -- 右脚
                { index = 19, class = "t-3" }                                                               -- 身
            }
        else
            led_config = {
                { index = 0, class = "cls-5", store = function(color) earlefttop_color = color end },       -- 左耳上
                { index = 1, class = "cls-8" },                                                             -- 左眼
                { index = 2, class = "cls-1" },                                                             -- 脸
                { index = 3, class = "cls-9" },                                                             -- 右眼
                { index = 4, class = "cls-7", store = function(color) earrighttop_color = color end },      -- 右耳上
                { index = 5, class = "cls-6", store = function(color) earrightmiddle_color = color end },   -- 右耳中
                { index = 6, class = "cls-11", store = function(color) earleftmiddle_color = color end },   -- 左耳中
                { index = 7, class = "cls-13", store = function(color) earleftbottom_color = color end },   -- 左耳下
                { index = 8, class = "cls-1" },                                                             -- 脸
                { index = 9, class = "cls-10" },                                                            -- 鼻
                { index = 10, class = "cls-1" },                                                            -- 脸
                { index = 11, class = "cls-12", store = function(color) earrightbottom_color = color end }, -- 右耳下
                { index = 12, class = "cls-1" },                                                            -- 脸
                { index = 13, class = "cls-1" },                                                            -- 脸
                { index = 14, class = "cls-1" },                                                            -- 脸
                { index = 15, class = "cls-2" },                                                            -- 身
                { index = 16, class = "cls-3" },                                                            -- 左脚
                { index = 17, class = "cls-2" },                                                            -- 身
                { index = 18, class = "cls-4" },                                                            -- 右脚
                { index = 19, class = "cls-2" }                                                             -- 身
            }
        end

        for _, config in ipairs(led_config) do
            if colorMap[config.class] then
                local color_value = tonumber(colorMap[config.class]:sub(2), 16)
                set_led_color(config.index, color_value)

                if config.store then
                    config.store(color_value)
                end
            end
        end

        if iot_msg["led"]["frametime"] then
            frame_time = iot_msg["led"]["frametime"]
        end
        if iot_msg["led"]["mode"] == "animation" then
            showing_time = false
            showing_battery = false
            if not run_animation then
                run_animation = true
                sys.taskInit(flap_wing)
            end
        elseif iot_msg["led"]["mode"] == "battery" then
            run_animation = false
            showing_time = false
            if not showing_battery then
                showing_battery = true
                sys.taskInit(show_battery)
            end
        elseif iot_msg["led"]["mode"] == "time" then
            run_animation = false
            showing_battery = false
            if not showing_time then
                showing_time = true
                sys.taskInit(show_time)
            end
        else
            showing_time = false
            run_animation = false
            showing_battery = false
            send_ws2812_data()
        end
    end
    local voltage = read_battery_voltage()
    local battery_level = calculate_battery_level(voltage)
    local level = math.floor(battery_level + 0.5)
    local bpayload = string.format(
        [[{"battery":%d}]],
        level
    )
    aliyun.publish(
        "/**/**/**", --替换
        1,
        bpayload
    )
    -- print("收到消息: topic=" .. topic .. ", payload=" .. payload)
end)


-- 初始化GNSS
init_gnss()

StatusLED(1)
sys.timerStart(low_power, 120000) -- 2分钟不操作进入低功耗模式
sys.taskInit(ntp_time_sync)
ws2812_init()
-- 启动系统主循环
sys.run()
