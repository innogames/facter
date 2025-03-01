describe Facter::Core::Execution::Posix, unless: LegacyFacter::Util::Config.windows? do
  let(:posix_executor) { Facter::Core::Execution::Posix.new }

  describe '#search_paths' do
    it 'uses the PATH environment variable plus /sbin and /usr/sbin on unix' do
      allow(ENV).to receive(:[]).with('PATH').and_return '/bin:/usr/bin'
      expect(posix_executor.search_paths). to eq %w[/bin /usr/bin /sbin /usr/sbin]
    end
  end

  describe '#which' do
    before do
      allow(posix_executor).to receive(:search_paths).and_return ['/bin', '/sbin', '/usr/sbin']
    end

    context 'when provided with an absolute path' do
      it 'returns the binary if executable' do
        allow(File).to receive(:executable?).with('/opt/foo').and_return(true)
        allow(FileTest).to receive(:file?).with('/opt/foo').and_return true
        expect(posix_executor.which('/opt/foo')).to eq '/opt/foo'
      end

      it 'returns nil if the binary is not executable' do
        allow(File).to receive(:executable?).with('/opt/foo').and_return(false)
        expect(posix_executor.which('/opt/foo')).to be nil
      end

      it 'returns nil if the binary is not a file' do
        allow(File).to receive(:executable?).with('/opt/foo').and_return(true)
        allow(FileTest).to receive(:file?).with('/opt/foo').and_return false
        expect(posix_executor.which('/opt/foo')).to be nil
      end
    end

    context "when it isn't provided with an absolute path" do
      it 'returns the absolute path if found' do
        allow(File).to receive(:executable?).with('/bin/foo').and_return false
        allow(FileTest).to receive(:file?).with('/sbin/foo').and_return true
        allow(File).to receive(:executable?).with('/sbin/foo').and_return true
        expect(posix_executor.which('foo')).to eq '/sbin/foo'
      end

      it 'returns nil if not found' do
        allow(File).to receive(:executable?).with('/bin/foo').and_return false
        allow(File).to receive(:executable?).with('/sbin/foo').and_return false
        allow(File).to receive(:executable?).with('/usr/sbin/foo').and_return false
        expect(posix_executor.which('foo')).to be nil
      end
    end
  end

  describe '#expand_command' do
    it 'expands binary' do
      allow(posix_executor).to receive(:which).with('foo').and_return '/bin/foo'
      expect(posix_executor.expand_command('foo -a | stuff >> /dev/null')).to eq '/bin/foo -a | stuff >> /dev/null'
    end

    it 'expands double quoted binary' do
      allow(posix_executor).to receive(:which).with('/tmp/my foo').and_return '/tmp/my foo'
      expect(posix_executor.expand_command('"/tmp/my foo" bar')).to eq "'/tmp/my foo' bar"
    end

    it 'expands single quoted binary' do
      allow(posix_executor).to receive(:which).with('my foo').and_return '/home/bob/my path/my foo'
      expect(posix_executor.expand_command("'my foo' -a")).to eq "'/home/bob/my path/my foo' -a"
    end

    it 'quotes expanded binary if found in path with spaces' do
      allow(posix_executor).to receive(:which).with('foo.sh').and_return '/home/bob/my tools/foo.sh'
      expect(posix_executor.expand_command('foo.sh /a /b')).to eq "'/home/bob/my tools/foo.sh' /a /b"
    end

    it 'expands a multi-line command with single quotes' do
      allow(posix_executor).to receive(:which).with('dpkg-query').and_return '/usr/bin/dpkg-query'
      expect(posix_executor.expand_command(
               "dpkg-query --showformat='${PACKAGE} ${VERSION}\n' --show | egrep '(^samba)"
             )).to eq("/usr/bin/dpkg-query --showformat='${PACKAGE} ${VERSION}\n' --show | egrep '(^samba)")
    end

    it 'expands a multi-line command with double quotes' do
      allow(posix_executor).to receive(:which).with('dpkg-query').and_return '/usr/bin/dpkg-query'
      expect(posix_executor.expand_command(
               "dpkg-query --showformat='${PACKAGE} ${VERSION}\n\" --show | egrep \"(^samba)"
             )).to eq("/usr/bin/dpkg-query --showformat='${PACKAGE} ${VERSION}\n\" --show | egrep \"(^samba)")
    end

    it 'returns nil if not found' do
      allow(posix_executor).to receive(:which).with('foo').and_return nil
      expect(posix_executor.expand_command('foo -a | stuff >> /dev/null')).to be nil
    end
  end

  describe '#absolute_path?' do
    %w[/ /foo /foo/../bar //foo //Server/Foo/Bar //?/C:/foo/bar /\Server/Foo /foo//bar/baz].each do |path|
      it "returns true for #{path}" do
        expect(posix_executor).to be_absolute_path(path)
      end
    end

    %w[. ./foo \foo C:/foo \\Server\Foo\Bar \\?\C:\foo\bar \/?/foo\bar \/Server/foo foo//bar/baz].each do |path|
      it "returns false for #{path}" do
        expect(posix_executor).not_to be_absolute_path(path)
      end
    end
  end

  context 'when calling execute_command' do
    let(:logger) { instance_spy(Logger) }

    it 'executes a command' do
      expect(posix_executor.execute_command('/usr/bin/true', nil, logger)).to eq(['', ''])
    end

    it "raises if 'on_fail' argument is specified" do
      expect do
        posix_executor.execute_command('/bin/notgoingtofindit', :raise)
      end.to raise_error(Facter::Core::Execution::ExecutionFailure, %r{Failed while executing '/bin/notgoingtofindit'})
    end

    it 'returns nil if the command fails by default' do
      expect(posix_executor.execute_command('/bin/notgoingtofindit')).to be_nil
    end

    it 'returns stdout string if the command fails and a logger was specified (!?)' do
      expect(posix_executor.execute_command('/bin/notgoingtofindit', nil, logger)).to eq('')
    end

    it 'returns a mutable stdout string' do
      expect(posix_executor.execute_command('/bin/notgoingtofindit', nil, logger)).not_to be_frozen
    end
  end
end
