module Rednode::Bindings
  class Evals
    include Namespace
    class Script
      def initialize(source)
        @source = source
      end

      def self.createContext(properties = {})
        ::Rednode::Bindings::Evals::Context.new(properties)
      end

      def createContext(*args)
        self.class.createContext(*args)
      end

      def self.runInContext(source, context)
        new(source).runInContext(context)
      end

      def runInContext(context)
        context.send(:eval, @source)
      end

      def self.runInNewContext
        lambda do |source, *args|
          sandbox, filename = *args
          new(source).runInNewContext(sandbox, filename)
        end
      end

      def runInNewContext(sandbox = nil, filename = nil)
        newContext = V8::Context.new
        sandbox = nil unless sandbox.kind_of?(V8::Object)
        for key, value in sandbox
          newContext[key] = value
        end if sandbox
        newContext.eval(@source, filename || "<script>").tap do
          for key, value in newContext.scope
            sandbox[key] = value
          end if sandbox
        end
      end

      def self.runInThisContext(source, filename = nil)
        new(source).runInThisContext(filename)
      end

      def runInThisContext(filename = nil)
        #mini-hack: there isn't a way to get the current V8::Context
        #as a high level context in therubyracer, so we hack the constructor
        #we wished existed that binds to the underlying current C::Context
        thisContext = V8::Context.allocate
        thisContext.instance_eval do
          @native = V8::C::Context::GetEntered()
          @to = V8::Portal.new(thisContext, V8::Access.new)
          @scope = @to.rb(@native.Global())
        end
        thisContext.eval(@source, filename || "<script>")
      end

    end

    class Context
      def initialize(properties)
        @cxt = ::V8::Context.new
        for k,v in properties
          @cxt[k] = v
        end
      end

      protected

      def eval(source)
        @cxt.eval(source)
      end

      def [](name)
        @cxt[name]
      end
    end
  end
end