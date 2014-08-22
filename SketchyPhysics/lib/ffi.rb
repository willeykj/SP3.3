dir = File.dirname(__FILE__)
path = File.join(dir, "#{RUBY_VERSION[0,3]}/ffi_c.so")
Object.send(:remove_const, :FFI) if defined?(::FFI)

if File.exists?(path)
  begin
    require path
    require File.join(dir, 'ffi/ffi.rb')
  rescue Exception => e
    raise "An error occurred while trying to load Ruby FFI!\n#{e}\n#{e.backtrace[0..2].join("\n")}"
  end
else
  raise "Ruby FFI is not supported for the current ruby version (#{RUBY_VERSION})!"
end
