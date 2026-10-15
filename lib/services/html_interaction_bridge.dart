import 'dart:convert';

enum HtmlInteractionPolicy { actions, localOnly }

/// Shared by the iframe and native WebView. Model JS is never executed.
class HtmlInteractionBridge {
  const HtmlInteractionBridge._();

  static String build(
      {required HtmlInteractionPolicy policy, String? webBridgeId}) {
    final transport = webBridgeId == null
        ? 'if(window.AiRoleplayBridge) window.AiRoleplayBridge.postMessage(value);'
        : 'window.parent.postMessage({type:"ai-roleplay-action",id:${jsonEncode(webBridgeId)},value:value},"*");';
    return '''(function(){
  var localOnly = ${policy == HtmlInteractionPolicy.localOnly};
  var snapshots = Array.from(document.querySelectorAll('[id],details')).map(function(el){return [el,el.hidden,el.open];});
  var style=document.createElement('style');style.textContent='[hidden]{display:none!important}button:focus-visible,summary:focus-visible{outline:3px solid #9461bf;outline-offset:3px}';document.head.appendChild(style);
  document.addEventListener('click',function(event){
    var target=event.target.closest?event.target:null;if(!target)return;
    var button=target.closest('[data-extra-action]');
    if(button){
      event.preventDefault();event.stopPropagation();
      var action=button.getAttribute('data-extra-action');
      if(action==='reset'){
        snapshots.forEach(function(s){s[0].hidden=s[1];if(s[0].tagName==='DETAILS')s[0].open=s[2];});
        document.querySelectorAll('[aria-pressed],[aria-expanded]').forEach(function(el){el.setAttribute('aria-pressed','false');el.setAttribute('aria-expanded','false');});return;
      }
      var panel=document.getElementById(button.getAttribute('data-extra-target')||'');if(!panel)return;
      if(action==='show'){
        var group=panel.getAttribute('data-extra-group');
        if(group)document.querySelectorAll('[data-extra-group]').forEach(function(el){if(el.getAttribute('data-extra-group')===group)el.hidden=true;});
        panel.hidden=false;
      }else if(action==='reveal'){panel.hidden=false;}else if(action==='toggle'){panel.hidden=!panel.hidden;}else{return;}
      button.setAttribute('aria-expanded',String(!panel.hidden));panel.setAttribute('aria-live','polite');return;
    }
    var legacy=target.closest('[data-prompt],[data-action],[data-ai-action],.rp-action,.rp-choice');
    if(!legacy)return;event.preventDefault();event.stopPropagation();
    if(localOnly)return;
    var value=(legacy.getAttribute('data-prompt')||legacy.getAttribute('data-action')||legacy.getAttribute('data-ai-action')||legacy.textContent||'').trim();
    if(value){$transport}
  },true);
})();''';
  }
}
