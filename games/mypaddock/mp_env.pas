unit mp_env;

{ App-specific host imports beyond pascaldom_env — mirrors Odin's
  mypaddock_env foreign block (date_now for wall-clock offline progress,
  js_reload for reset). NOTE: the web IDE host must provide these; if it
  does not, the module will fail to instantiate there (verify in IDE). }

interface

function mp_date_now: Double; external 'mp_env' name 'date_now';

procedure mp_js_reload; external 'mp_env' name 'js_reload';

implementation

begin
end.
