var cssFix = function(){
  var u = navigator.userAgent.toLowerCase(),
  addClass = function(el,val){
    if(!el.className) {
      el.className = val;
    } else {
      var newCl = el.className;
      newCl+=(" "+val);
      el.className = newCl;
    }
  },
  is = function(t){return (u.indexOf(t)!=-1)};
  addClass(document.getElementsByTagName('html')[0],[
    (!(/opera|webtv/i.test(u))&&/msie (\d)/.test(u))?('ie ie'+RegExp.$1)
      :is('firefox/2')?'gecko ff2'
      :is('firefox/3')?'gecko ff3'
      :is('gecko/')?'gecko'
      :is('opera/9')?'opera opera9':/opera (\d)/.test(u)?'opera opera'+RegExp.$1
      :is('konqueror')?'konqueror'
      :is('applewebkit/')?'webkit safari'
      :is('mozilla/')?'gecko':'',
    (is('x11')||is('linux'))?' linux'
      :is('mac')?' mac'
      :is('win')?' win':''
  ].join(" "));
}();