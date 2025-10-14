import mqtt, {
  isNull,
  stringify
} from '../../utils/mqtt.js';
const aliyunOpt = require('../../utils/aliyun/aliyun_connect.js');
const coordinateTransform = require('../../utils/coordinateTransform.js');
let positionreporttimer;
let that = null;
const INIT_MARKER = {
  id: 1,
  callout: {
    content: '100',
    padding: 10,
    borderRadius: 5,
    display: 'ALWAYS'
  },

  latitude: 40.040415,
  longitude: 116.273511,
  iconPath: '/assets/flypig logo.png',
  width: '55px',
  height: '34px',
  rotate: 0,
  alpha: 1
};
const isTest = false;
const TEST_OBJCOLOR = isTest ? {
  //test
  "t-1": "#000000",
  "t-2": "#000000",
  "t-3": "#000000",
  "t-4": "#000000",
  "t-5": "#000000",
  "t-6": "#000000"
} : {};
const INIT_COLOR = {
  "cls-1": "#E67661",
  "cls-2": "#E67661",
  "cls-3": "#E67661",
  "cls-4": "#E67661",
  "cls-5": "#E67661",
  "cls-6": "#000000",
  "cls-7": "#E67661",
  "cls-8": "#a5515f",
  "cls-9": "#a5515f",
  "cls-10": "#a5515f",
  "cls-11": "#000000",
  "cls-12": "#000000",
  "cls-13": "#000000",
  ...TEST_OBJCOLOR


};
const INIT_ANIMATION_COLOR = {
  "cls-1": "#E67661",
  "cls-2": "#E67661",
  "cls-3": "#E67661",
  "cls-4": "#E67661",
  "cls-5": "#E67661",
  "cls-6": "#E67661",
  "cls-7": "#E67661",
  "cls-8": "#a5515f",
  "cls-9": "#a5515f",
  "cls-10": "#a5515f",
  "cls-11": "#E67661",
  "cls-12": "#E67661",
  "cls-13": "#E67661",
  //test
  ...TEST_OBJCOLOR
};

Page({

  data: {
    tabList: [{
      name: '位置'
    }, {
      name: '颜色'
    }],

    markers: [{
      ...INIT_MARKER
    }],
    tabIndex: 0,
    scale: 15,
    location: {
      latitude: 40.040415,
      longitude: 116.273511
    },
    lastLocation: {
      latitude: 40.040415,
      longitude: 116.273511
    },
    locationFixed: false,
    mode: "",
    frameTime: 1000,
    parts: [{
        name: "左耳上",
        key: "cls-5"
      },
      {
        name: "左耳中",
        key: "cls-11"
      },
      {
        name: "左耳下",
        key: "cls-13"
      },
      {
        name: "右耳上",
        key: "cls-7"
      },
      {
        name: "右耳中",
        key: "cls-6"
      },
      {
        name: "右耳下",
        key: "cls-12"
      },
      {
        name: "左眼",
        key: "cls-8"
      },
      {
        name: "右眼",
        key: "cls-9"
      },
      {
        name: "鼻",
        key: "cls-10"
      },
      {
        name: "脸",
        key: "cls-1"
      },
      {
        name: "身",
        key: "cls-2"
      },
      {
        name: "左脚",
        key: "cls-3"
      },
      {
        name: "右脚",
        key: "cls-4"
      },
      {
        name: "关闭",
        key: "close"
      },
      {
        name: "默认",
        key: "init"
      },
      //   test
      ...(isTest ? [{
          name: "t1",
          key: "t-1"
        },
        {
          name: "t2",
          key: "t-2"
        },
        {
          name: "t3",
          key: "t-3"
        },
        {
          name: "t4",
          key: "t-4"
        },
        {
          name: "t5",
          key: "t-5"
        },
        {
          name: "t6",
          key: "t-6"
        }
      ] : [])
    ],
    currentPart: {
      name: "左耳上",
      key: "cls-5"
    },
    currentColor: {
      r: 0,
      g: 0,
      b: 0
    },
    colorObject: {
      "cls-1": "#E67661",
      "cls-2": "#E67661",
      "cls-3": "#E67661",
      "cls-4": "#E67661",
      "cls-5": "#E67661",
      "cls-6": "#000000",
      "cls-7": "#E67661",
      "cls-8": "#a5515f",
      "cls-9": "#a5515f",
      "cls-10": "#a5515f",
      "cls-11": "#000000",
      "cls-12": "#000000",
      "cls-13": "#000000",
      //test
      ...TEST_OBJCOLOR
    },
    //阿里云
    client: null, //记录重连的次数
    reconnectCounts: 0, //MQTT连接的配置
    options: {
      protocolVersion: 4, //MQTT连接协议版本
      clean: false,
      reconnectPeriod: 1000, //1000毫秒，两次重新连接之间的间隔
      connectTimeout: 30 * 1000, //1000毫秒，两次重新连接之间的间隔
      resubscribe: true, //如果连接断开并重新连接，则会再次自动订阅已订阅的主题（默认true）
      clientId: '',
      password: '',
      username: '',
    },
    message: {
      messageArrived: 0,
      messageObject: null,
      cntTime: 0,
    },
    aliyunInfo: {
      productKey: '替换', //阿里云连接的三元组 ，请自己替代为自己的产品信息!!
      deviceName: '替换', //阿里云连接的三元组 ，请自己替代为自己的产品信息!!
      deviceSecret: '替换', //阿里云连接的三元组 ，请自己替代为自己的产品信息!!
      regionId: 'cn-shanghai', //阿里云连接的三元组 ，请自己替代为自己的产品信息!!
      pubTopic: '/**/**/**', //发布消息的主题
      subTopic: '/**/**/**', //订阅消息的主题
    }
  },

  onUnload: function () {
    this.data.client.end(), clearInterval(positionreporttimer)
    let sendData = {
      locationreport: 0
    }
    this.data.client.publish(this.data.aliyunInfo.pubTopic, JSON.stringify(sendData));
    try {
      wx.setStorageSync('lastlocation', this.data.lastLocation)
      wx.setStorageSync('fixed', this.data.locationFixed)
    } catch (e) {
      console.error('存储失败', e)
    }
  },
  onLoad: function () {
    that = this;
    let ll = this.data.lastLocation;
    try {
      const locfixed = wx.getStorageSync('fixed');
      if (locfixed) {
        ll = wx.getStorageSync('lastlocation');
      }
      console.log(ll);
    } catch (e) {
      console.error('读取失败', e);
    }
    let clientOpt = aliyunOpt.getAliyunIotMqttClient({
      productKey: that.data.aliyunInfo.productKey,
      deviceName: that.data.aliyunInfo.deviceName,
      deviceSecret: that.data.aliyunInfo.deviceSecret,
      regionId: that.data.aliyunInfo.regionId,
      port: that.data.aliyunInfo.port,
    });
    console.log("map--get data:" + JSON.stringify(clientOpt));
    let host = 'wxs://' + clientOpt.host;
    console.log("map--get data:" + JSON.stringify(clientOpt));
    this.setData({
      'options.clientId': clientOpt.clientId,
      'options.password': clientOpt.password,
      'options.username': clientOpt.username,
      lastLocation: ll,
      location: ll,
      'markers[0].latitude': ll.latitude,
      'markers[0].longitude': ll.longitude
    })
    console.log("map--this.data.options host:" + host);
    console.log("map--this.data.options data:" + JSON.stringify(this.data.options));

    this.data.client = mqtt.connect(host, this.data.options);
    that.data.client.subscribe(this.data.aliyunInfo.subTopic);
    this.data.client.on('connect', function () {
      let sendData = {
        locationreport: 1
      };
      positionreporttimer = setInterval(function positionReport() {
        that.data.client.publish(that.data.aliyunInfo.pubTopic, JSON.stringify(sendData), 1)
      }, 10000)
    });
    that.data.client.on("message", function (topic, payload) {
      console.log(" 收到 topic:" + topic + " , payload :" + payload)
      let msg = that.data.message.messageObject;
      msg = JSON.parse(payload); 
      that.data.message.messageArrived = 1;
      that.data.message.cntTime = 0;
      if (msg.GeoLocation && msg.GeoLocation.Latitude && msg.GeoLocation.Longitude != null) {
        var loc = {
          latitude: msg.GeoLocation.Latitude,
          longitude: msg.GeoLocation.Longitude
        };
        const gcj02Coord = coordinateTransform.wgs84ToGcj02(loc.longitude, loc.latitude)

        that.setData({
          location: gcj02Coord,
          lastLocation: gcj02Coord,
          locationFixed: true,
          'markers[0].latitude': gcj02Coord.latitude,
          'markers[0].longitude': gcj02Coord.longitude
        })
        console.log("latitude:" + gcj02Coord.latitude)
        console.log("longitude" + gcj02Coord.longitude)
      }
      if (msg.battery != null) {
        const battery = msg.battery;
        console.log(battery);

        that.setData({
          'markers[0].callout.content': "电量" + battery
        })
      }

    })
    //服务器连接异常的回调
    that.data.client.on("error", function (error) {
      clearInterval(positionreporttimer);
      console.log(" 服务器 error 的回调" + error)

    })
    //服务器重连连接异常的回调
    that.data.client.on("reconnect", function () {
      console.log(" 服务器 reconnect的回调")

    })
    //服务器连接异常的回调
    that.data.client.on("offline", function (errr) {
      clearInterval(positionreporttimer);
      console.log(" 服务器offline的回调")
    })

  },
  onClickTab(event) {
    this.setData({
      tabIndex: event.detail.current,
      scale: 15,
      location: this.data.lastLocation
    });
  },
  onLocationButtonTap() {
    this.setData({
      location: this.data.lastLocation
    });
  },

  selectPart(e) {
    const part = e.currentTarget.dataset.part;
    const key = e.currentTarget.dataset.key;

    if (part === "关闭") {
      const newColorObject = {
        ...this.data.colorObject
      };
      for (let k in newColorObject) {
        newColorObject[k] = "#000000"; 
      }

      this.setData({
        currentPart: {
          part: part,
          key: key
        },
        colorObject: newColorObject
      });
      return;
    } else if (part == "默认") {
      this.setData({
        currentPart: {
          part: part,
          key: key
        },
        colorObject: INIT_COLOR
      });
      return;
    }
    const hex = this.data.colorObject[key];
    const rgb = this.hexToRgb(hex);
    this.setData({
      currentPart: {
        name: part,
        key: key
      },
      currentColor: rgb
    });
  },

  onRadioChange(e) {
    if (e.detail.value == "animation") {
      this.setData({
        mode: e.detail.value,
        colorObject: INIT_ANIMATION_COLOR
      });
    } else
      this.setData({
        mode: e.detail.value
      });
  },
  onSliderChange(e) {
    const channel = e.currentTarget.dataset.channel;
    const value = e.detail.value;
    const color = {
      ...this.data.currentColor,
      [channel]: value
    };

    const hex = "#" + [color.r, color.g, color.b]
      .map(v => v.toString(16).padStart(2, "0"))
      .join("");
    this.setData({
      currentColor: color,
      [`colorObject.${this.data.currentPart.key}`]: hex
    });
    console.log("colorObject:", this.data.colorObject);

    console.log("Slider -> Hex 同步:", color, hex);
  },
  onHexInput(e) {
    const hex = e.detail.value.trim();
    if (/^#([0-9a-fA-F]{6})$/.test(hex)) {
      const r = parseInt(hex.slice(1, 3), 16);
      const g = parseInt(hex.slice(3, 5), 16);
      const b = parseInt(hex.slice(5, 7), 16);

      this.setData({
        [`colorObject.${this.data.currentPart.key}`]: hex,
        currentColor: {
          r,
          g,
          b
        }
      });
      console.log("Hex -> RGB 同步:", hex, r, g, b);
    } else {
      wx.showToast({
        title: "请输入正确的#RRGGBB格式",
        icon: "none"
      });
    }
  },
  onFrameTimeInput(e) {
    const value = Number(e.detail.value);
    const frameTime = isNaN(value) ? this.data.frametime : value;
    this.setData({
      frameTime: frameTime
    });
    console.log("当前帧时间为：", this.data.frameTime);
  },
  rgbToHex({
    r,
    g,
    b
  }) {
    const toHex = n => n.toString(16).padStart(2, "0");
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  },

  hexToRgb(hex) {
    const bigint = parseInt(hex.slice(1), 16);
    return {
      r: (bigint >> 16) & 255,
      g: (bigint >> 8) & 255,
      b: bigint & 255
    };
  },
  hexRgbToGrb(hex) {
    if (!/^#([0-9a-fA-F]{6})$/.test(hex)) {
      throw new Error("输入必须是 #RRGGBB 格式");
    }
    const r = hex.slice(1, 3);
    const g = hex.slice(3, 5);
    const b = hex.slice(5, 7);
    return `#${g}${r}${b}`;
  },
  ws2812bColorCorrect(inhex) {

    const kR = 0.45;
    const kG = 0.45;
    const kB = 0.50;
    const gamma = 2.0;
    const brightness = 0.5;
    const {
      r,
      g,
      b
    } = this.hexToRgb(inhex);
    let rr = r * kR * brightness;
    let gg = g * kG * brightness;
    let bb = b * kB * brightness;

    rr = Math.min(255, rr);
    gg = Math.min(255, gg);
    bb = Math.min(255, bb);

    rr = Math.pow(rr / 255, gamma) * 255;
    gg = Math.pow(gg / 255, gamma) * 255;
    bb = Math.pow(bb / 255, gamma) * 255;
    let outR = Math.round(rr);
    let outG = Math.round(gg);
    let outB = Math.round(bb);
    const hexRGB = this.rgbToHex({
      r: outR,
      g: outG,
      b: outB
    });
    return hexRGB;
  },

  submit() {
    const payload = Object.keys(this.data.colorObject).map(k => {
      const hex = this.data.colorObject[k];
      const ws2812hex = this.ws2812bColorCorrect(hex);
      const c = this.hexRgbToGrb(ws2812hex);
      console.log("显示颜色：", hex, "ws2812颜色：", c);
      return {
        partKey: k,
        color: c
      };

    });
    let sendData = {
      led: {
        mode: this.data.mode,
        //test
        ...(isTest && {
          test: true
        }),
        frametime: this.data.frameTime,
        color: payload,
      }
    }
    this.data.client.publish(this.data.aliyunInfo.pubTopic, JSON.stringify(sendData));
  },
});