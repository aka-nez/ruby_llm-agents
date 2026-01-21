# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workflows Run/Execute", type: :request do
  describe "GET /workflows/:id/run" do
    # Mock workflow class for testing
    let(:mock_workflow_class) do
      Class.new do
        def self.name
          "TestPipelineWorkflow"
        end

        def self.respond_to?(method, *)
          %i[params description].include?(method) || super
        end

        def self.params
          {input: {required: true}}
        end

        def self.description
          "A test pipeline workflow"
        end

        def self.ancestors
          [RubyLLM::Agents::Workflow::Pipeline]
        end
      end
    end

    context "with existing workflow" do
      before do
        create(:execution,
          agent_type: "TestPipelineWorkflow",
          workflow_type: "pipeline")
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("TestPipelineWorkflow").and_return(mock_workflow_class)
      end

      it "returns JSON with workflow metadata" do
        get ruby_llm_agents.run_workflow_path(id: "TestPipelineWorkflow"), as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("TestPipelineWorkflow")
        expect(json["params"]).to be_a(Hash)
        expect(json["params"]).to have_key("input")
      end

      it "includes workflow_type" do
        get ruby_llm_agents.run_workflow_path(id: "TestPipelineWorkflow"), as: :json
        json = JSON.parse(response.body)
        expect(json).to have_key("workflow_type")
      end

      it "includes supports_attachments as false" do
        get ruby_llm_agents.run_workflow_path(id: "TestPipelineWorkflow"), as: :json
        json = JSON.parse(response.body)
        expect(json["supports_attachments"]).to be false
      end

      it "includes description if present" do
        get ruby_llm_agents.run_workflow_path(id: "TestPipelineWorkflow"), as: :json
        json = JSON.parse(response.body)
        expect(json).to have_key("description")
      end
    end

    context "with non-existent workflow" do
      before do
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("NonExistentWorkflow").and_return(nil)
      end

      it "returns 404 not found" do
        get ruby_llm_agents.run_workflow_path(id: "NonExistentWorkflow"), as: :json
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Workflow not found")
      end
    end
  end

  describe "POST /workflows/:id/execute" do
    let(:mock_result) { double("Result") }

    # Mock workflow class for testing
    let(:mock_workflow_class) do
      Class.new do
        def self.name
          "TestPipelineWorkflow"
        end

        def self.respond_to?(method, *)
          %i[params call].include?(method) || super
        end

        def self.params
          {input: {required: true}}
        end

        def self.call(**params)
          # Mock execution
        end

        def self.ancestors
          [RubyLLM::Agents::Workflow::Pipeline]
        end
      end
    end

    context "with existing workflow" do
      before do
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("TestPipelineWorkflow").and_return(mock_workflow_class)
        allow(mock_workflow_class).to receive(:call).and_return(mock_result)
      end

      it "executes workflow and redirects to execution" do
        execution = create(:execution, agent_type: "TestPipelineWorkflow", workflow_type: "pipeline")
        post ruby_llm_agents.execute_workflow_path(id: "TestPipelineWorkflow"),
          params: {workflow_params: {input: "test"}}
        expect(response).to redirect_to(ruby_llm_agents.execution_path(execution))
        follow_redirect!
        expect(flash[:notice]).to include("successfully")
      end

      it "passes params to workflow" do
        create(:execution, agent_type: "TestPipelineWorkflow", workflow_type: "pipeline")
        expect(mock_workflow_class).to receive(:call).with(hash_including(input: "test"))
        post ruby_llm_agents.execute_workflow_path(id: "TestPipelineWorkflow"),
          params: {workflow_params: {input: "test"}}
      end

      context "when no execution record is found" do
        before do
          RubyLLM::Agents::Execution.where(agent_type: "TestPipelineWorkflow").delete_all
        end

        it "redirects to executions index with notice" do
          post ruby_llm_agents.execute_workflow_path(id: "TestPipelineWorkflow"),
            params: {workflow_params: {input: "test"}}
          expect(response).to redirect_to(ruby_llm_agents.executions_path)
          follow_redirect!
          expect(flash[:notice]).to include("no execution record")
        end
      end
    end

    context "with non-existent workflow" do
      before do
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("NonExistentWorkflow").and_return(nil)
      end

      it "redirects with error flash" do
        post ruby_llm_agents.execute_workflow_path(id: "NonExistentWorkflow"),
          params: {workflow_params: {input: "test"}}
        expect(response).to redirect_to(ruby_llm_agents.workflow_path(id: "NonExistentWorkflow"))
        follow_redirect!
        expect(flash[:alert]).to include("not found")
      end
    end

    context "when execution fails" do
      before do
        allow(RubyLLM::Agents::AgentRegistry).to receive(:find)
          .with("TestPipelineWorkflow").and_return(mock_workflow_class)
        allow(mock_workflow_class).to receive(:call).and_raise(StandardError.new("Workflow error"))
      end

      it "redirects back with error message" do
        post ruby_llm_agents.execute_workflow_path(id: "TestPipelineWorkflow"),
          params: {workflow_params: {input: "test"}}
        expect(response).to redirect_to(ruby_llm_agents.workflow_path(id: "TestPipelineWorkflow"))
        follow_redirect!
        expect(flash[:alert]).to include("failed")
        expect(flash[:alert]).to include("Workflow error")
      end
    end
  end
end
