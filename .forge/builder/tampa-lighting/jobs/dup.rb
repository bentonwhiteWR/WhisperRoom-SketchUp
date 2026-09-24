sc = VRay::Context.active.scene
r = ['/RenderView', '/RenderView#1'].map { |n| p = sc[n]; [n, p[:transform].inspect[0, 300], p[:fov], p[:orthographic]] }
o = ['/SettingsOutput', '/SettingsOutput#1'].map { |n| [n, sc[n][:img_width], sc[n][:img_height]] }
c = ['/CameraPhysical', '/CameraPhysical#1'].map { |n| [n, sc[n][:ISO], sc[n][:shutter_speed], sc[n][:f_number], sc[n][:use_dof], sc[n][:specify_fov], sc[n][:fov]] }
s = ['/SunLight', '/SunLight#1'].map { |n| [n, sc[n][:enabled], sc[n][:intensity_multiplier], sc[n][:transform].inspect[0, 200]] }
[r, o, c, s]
