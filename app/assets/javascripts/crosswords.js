String.prototype.format = function(values) {
  var regex = /\{([\w-]+)(?:\:([\w\.]*)(?:\((.*?)?\))?)?\}/g;

  var getValue = function(key) {
    if(values == null || typeof values === 'undefined')
      return null;

    var value = values[key];
    var type = typeof value;

    return type === 'string' || type === 'number' ? value : null;
  };

  return this.replace(regex, function(match) { 
    //match will look like {sample-match}
    //key will be 'sample-match';
    var key = match.substr(1, match.length - 2);

    var value = getValue(key);

    return value != null ? value : match;
  });
};

//event.type must be keypress
function getChar(event) {
  if (event.which == null) {
    return String.fromCharCode(event.keyCode) // IE
  } else if (event.which!=0 && event.charCode!=0) {
    return String.fromCharCode(event.which)   // the rest
  } else {
    return null // special key
  }
}
