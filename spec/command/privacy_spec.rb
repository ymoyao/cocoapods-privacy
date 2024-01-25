require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Privacy do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ privacy }).should.be.instance_of Command::Privacy
      end
    end
  end
end

