import { encode } from './base64';

const fs = wx.getFileSystemManager();

Component({
  externalClasses: ['image-class'],
  properties: {
    src: String, // svg 资源地址，暂仅支持本地路径
    color: String, // svg 颜色
    colors: null, // svg 颜色配置，支持数组或对象
    mode: String, // svg 裁剪、缩放的模式
  },
  observers: {
    'src, color, colors'(src, color, colors) {
      try {
        if (color || (colors && (
          colors.length > 0 || Object.keys(colors).length > 0
        ))) {
          let data = fs.readFileSync(src, 'utf8');
          // eslint-disable-next-line no-param-reassign
          if (!colors) colors = {}; // 默认值
          if (/(fill|stroke)=".*?"/.test(data)) {
            let index = 0;
            data = data.replace(/(fill|stroke)=".*?"/g, (matched) => {
              // 获取原本颜色
              const matchedColor = matched.slice(matched.indexOf('"') + 1, -1);
              // 设置替换颜色
              const replaceColor = colors[index++] || colors[matchedColor] || color || matchedColor;

              if (/fill/.test(matched)) return `fill="${replaceColor}"`;
              if (/stroke/.test(matched)) return `stroke="${replaceColor}"`;
              return `fill="${replaceColor}"`;
            });
          } else {
            //  新增：className → colorObject 替换
            data = data.replace(/class="(.*?)"/g, (matched, cls) => {
                const replaceColor = colors[cls];
                if (replaceColor) {
                    // 如果没写 fill，就加上 fill
                    return `${matched} fill="${replaceColor}"`;
                }
                return matched;
            });
          }
          // 设置默认底色
          const defaultColor = colors['#000'] || colors['#000000'] || colors.black || color;
          // svg 标签是否包含底色
          if (defaultColor && !/fill=".*?"/.test(data.slice(0, data.indexOf('>')))) {
            data = data.replace(/<svg /, `<svg fill="${defaultColor}" `);
          }
          this.setData({
            base64: `data:image/svg+xml;base64, ${encode(data)}`,
          });
        } else {
          this.setData({
            base64: src,
          });
        }
      } catch (err) {
        console.error(err);
        this.triggerEvent('error', err);
      }
    },
  },
  data: {
    base64: '',
  },
  methods: {
    onImageError(e) {
      this.triggerEvent('error', e.detail);
    },
    onImageLoad(e) {
      this.triggerEvent('load', e.detail);
    },
  },
});
