# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Run Action Routes", type: :routing do
  routes { RubyLLM::Agents::Engine.routes }

  describe "agents" do
    it "routes GET /agents/:id/run to agents#run" do
      expect(get: "/agents/TestAgent/run").to route_to(
        controller: "ruby_llm/agents/agents",
        action: "run",
        id: "TestAgent"
      )
    end

    it "routes POST /agents/:id/execute to agents#execute" do
      expect(post: "/agents/TestAgent/execute").to route_to(
        controller: "ruby_llm/agents/agents",
        action: "execute",
        id: "TestAgent"
      )
    end
  end

  describe "workflows" do
    it "routes GET /workflows/:id/run to workflows#run" do
      expect(get: "/workflows/TestWorkflow/run").to route_to(
        controller: "ruby_llm/agents/workflows",
        action: "run",
        id: "TestWorkflow"
      )
    end

    it "routes POST /workflows/:id/execute to workflows#execute" do
      expect(post: "/workflows/TestWorkflow/execute").to route_to(
        controller: "ruby_llm/agents/workflows",
        action: "execute",
        id: "TestWorkflow"
      )
    end
  end
end
