// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".

//"JavaScript Next"-style

import "phoenix"
import "phoenix_html"

import $ from "jquery"

import "bootstrap"

// import "select2"

import "admin-lte/plugins/datepicker/bootstrap-datepicker"

import "admin-lte/plugins/input-mask/jquery.inputmask"

import "admin-lte/plugins/select2/select2.full.min"

import "admin-lte"

$(document).ready(function() {
  // trigger multiselect with search autocomplete
  $(".fancy").select2({
    placeholder: "Select an option",
    allowClear: true,
  });
  // trigger datepicker inputs
  $.fn.datepicker.defaults.format = 'yyyy-mm-dd';
  $.fn.datepicker.defaults.assumeNearbyYear = true;
  $.fn.datepicker.defaults.todayHighlight = true;
  $('div.date .form-control').datepicker();
  // trigger phone input masks
  $(":input").inputmask();
});

// "CommonJS"-style, see http://jsmodules.io/cjs.html for comparison
// global.$ = global.jQuery = require("jquery")
// global.bootstrap = require("bootstrap")
// global.AdminLTE = require("admin-lte")



// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"
