# frozen_string_literal: true

module Facts
  module Debian
    module Os
      class Architecture
        FACT_NAME = 'os.architecture'
        ALIASES = 'architecture'

        def call_the_resolver
          fact_value = Facter::Core::Execution.execute('dpkg --print-architecture')

          [Facter::ResolvedFact.new(FACT_NAME, fact_value), Facter::ResolvedFact.new(ALIASES, fact_value, :legacy)]
        end
      end
    end
  end
end
