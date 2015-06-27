document.body.style.overflow = 'hidden';

var $content = $('#content');
var tail_id = 0;
var id = 0;
var io = new RocketIO().connect();

function isVisible(el) {
  if (typeof jQuery === "function" && el instanceof jQuery) {
    el = el[0];
  }
  var rect = el.getBoundingClientRect();
  return (
    rect.top >= 0 &&
    rect.left >= 0 &&
    rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
    rect.right <= (window.innerWidth || document.documentElement.clientWidth)
  );
}

io.on('msg', function(data) {
  $content.prepend('<tr id="msg' + id + '"></div>');
  $('#msg' + id).html(data).effect("highlight", 500);
  id++;
  var tail = $('#msg' + tail_id);
  if (!isVisible(tail)) {
    tail.remove();
    tail_id++;
  };
});
