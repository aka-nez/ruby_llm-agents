# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agents Run/Execute", type: :request do
  describe "GET /agents/:id/run" do
    context "with existing agent" do
      it "returns JSON with agent metadata" do
        get ruby_llm_agents.run_agent_path(id: "TestAgent"), as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("TestAgent")
        expect(json["params"]).to be_a(Hash)
        expect(json["params"]).to have_key("query")
        expect(json["params"]).to have_key("limit")
      end

      it "includes model information" do
        get ruby_llm_agents.run_agent_path(id: "TestAgent"), as: :json
        json = JSON.parse(response.body)
        expect(json["model"]).to eq("gpt-4")
      end

      it "includes supports_attachments flag" do
        get ruby_llm_agents.run_agent_path(id: "TestAgent"), as: :json
        json = JSON.parse(response.body)
        expect(json).to have_key("supports_attachments")
        expect(json["supports_attachments"]).to be_in([true, false])
      end

      it "includes description if present" do
        get ruby_llm_agents.run_agent_path(id: "TestAgent"), as: :json
        json = JSON.parse(response.body)
        expect(json).to have_key("description")
      end
    end

    context "with non-existent agent" do
      before do
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("NonExistentAgent").and_return(nil)
      end

      it "returns 404 not found" do
        get ruby_llm_agents.run_agent_path(id: "NonExistentAgent"), as: :json
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Agent not found")
      end
    end
  end

  describe "POST /agents/:id/execute" do
    let(:mock_result) { double("Result") }

    context "with existing agent" do
      before do
        allow(TestAgent).to receive(:call).and_return(mock_result)
      end

      it "executes agent and redirects to execution" do
        execution = create(:execution, agent_type: "TestAgent")
        post ruby_llm_agents.execute_agent_path(id: "TestAgent"),
          params: {agent_params: {query: "test"}}
        expect(response).to redirect_to(ruby_llm_agents.execution_path(execution))
        follow_redirect!
        expect(flash[:notice]).to include("successfully")
      end

      it "passes params to agent" do
        create(:execution, agent_type: "TestAgent")
        expect(TestAgent).to receive(:call).with(hash_including(query: "test"))
        post ruby_llm_agents.execute_agent_path(id: "TestAgent"),
          params: {agent_params: {query: "test"}}
      end

      context "when no execution record is found" do
        before do
          RubyLLM::Agents::Execution.where(agent_type: "TestAgent").delete_all
        end

        it "redirects to executions index with notice" do
          post ruby_llm_agents.execute_agent_path(id: "TestAgent"),
            params: {agent_params: {query: "test"}}
          expect(response).to redirect_to(ruby_llm_agents.executions_path)
          follow_redirect!
          expect(flash[:notice]).to include("no execution record")
        end
      end
    end

    context "with non-existent agent" do
      before do
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("NonExistentAgent").and_return(nil)
      end

      it "redirects with error flash" do
        post ruby_llm_agents.execute_agent_path(id: "NonExistentAgent"),
          params: {agent_params: {query: "test"}}
        expect(response).to redirect_to(ruby_llm_agents.agent_path(id: "NonExistentAgent"))
        follow_redirect!
        expect(flash[:alert]).to include("not found")
      end
    end

    context "when execution fails" do
      before do
        allow(TestAgent).to receive(:call).and_raise(StandardError.new("API error"))
      end

      it "redirects back with error message" do
        post ruby_llm_agents.execute_agent_path(id: "TestAgent"),
          params: {agent_params: {query: "test"}}
        expect(response).to redirect_to(ruby_llm_agents.agent_path(id: "TestAgent"))
        follow_redirect!
        expect(flash[:alert]).to include("failed")
        expect(flash[:alert]).to include("API error")
      end
    end

    # NOTE: Parameter coercion tests are in agents_controller_spec.rb
    # as unit tests since they test internal controller implementation details
  end
end
