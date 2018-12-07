require 'rails_helper'
describe ReviewMappingController do
  let(:assignment) { double('Assignment', id: 1) }
  let(:review_response_map) do
    double('ReviewResponseMap', id: 1, map_id: 1, assignment: assignment,
          reviewer: double('Participant', id: 1, name: 'reviewer'), reviewee: double('Participant', id: 2, name: 'reviewee'))
  end
  let(:metareview_response_map) do
    double('MetareviewResponseMap', id: 1, map_id: 1, assignment: assignment,
          reviewer: double('Participant', id: 1, name: 'reviewer'), reviewee: double('Participant', id: 2, name: 'reviewee'))
  end
  let(:map) { double('ResponseMap', id: 1)}

  let(:reviewer) { double('AssignmentParticipant', user_id: 1, parent_id: 1, reviewer_id: 1, id: 1)}
  let(:review_map) { double('ReviewResponseMap', reviewee_id: 1, reviewer_id: 1, map_id: 1)}
  let(:participant) { double('AssignmentParticipant', id: 1, can_review: false, user: double('User', id: 1)) }
  let(:participant1) { double('AssignmentParticipant', id: 2, can_review: true, user: double('User', id: 2)) }
  let(:user) { double('User', id: 3) }
  let(:participant2) { double('AssignmentParticipant', id: 3, can_review: true, user: user) }
  let(:team) { double('AssignmentTeam', name: 'no one', id: 1, parent_id: 1, id: 1) }
  let(:team1) { double('AssignmentTeam', name: 'no one1') }

  before(:each) do
    allow(Assignment).to receive(:find).with('1').and_return(assignment)
    instructor = build(:instructor)
    stub_current_user(instructor, instructor.role.name, instructor.role)
  end

  describe '#add_calibration' do
    context 'when both participant and review_response_map have already existed' do
      it 'does not need to create new objects and redirects to responses#new maps' do
        allow(AssignmentParticipant).to receive_message_chain(:where, :first)
          .with(parent_id: '1', user_id: 1).with(no_args).and_return(participant)
        allow(ReviewResponseMap).to receive_message_chain(:where, :first)
          .with(reviewed_object_id: '1', reviewer_id: 1, course_staff: true, reviewee_id: '1', calibrate_to: true).with(no_args).and_return(review_response_map)
        params = {id: 1, team_id: 1}
        session = {user: build(:instructor, id: 1)}
        get :add_calibration, params, session
        expect(response).to redirect_to '/response/new?assignment_id=1&id=1&return=assignment_edit'
      end
    end

    context 'when both participant and review_response_map have not been created' do
      it 'creates new objects and redirects to responses#new maps' do
        allow(AssignmentParticipant).to receive_message_chain(:where, :first)
          .with(parent_id: '1', user_id: 1).with(no_args).and_return(nil)
        allow(AssignmentParticipant).to receive(:create)
          .with(parent_id: '1', user_id: 1, can_submit: 1, can_review: 1, can_take_quiz: 1, handle: 'handle').and_return(participant)
        allow(ReviewResponseMap).to receive_message_chain(:where, :first)
          .with(reviewed_object_id: '1', reviewer_id: 1, reviewee_id: '1', calibrate_to: true).with(no_args).and_return(nil)
        allow(ReviewResponseMap).to receive(:create)
          .with(reviewed_object_id: '1', course_staff: true, reviewer_id: 1, reviewee_id: '1', calibrate_to: true).and_return(review_response_map)
        params = {id: 1, team_id: 1}
        session = {user: build(:instructor, id: 1)}
        get :add_calibration, params, session
        expect(response).to redirect_to '/response/new?assignment_id=1&id=1&return=assignment_edit'
      end
    end
  end

  describe '#add_reviewer and #get_reviewer' do
    before(:each) do
      allow(User).to receive_message_chain(:where, :first).with(name: 'expertiza').with(no_args).and_return(double('User', id: 1))
      @params = {
        id: 1,
        topic_id: 1,
        user: {name: 'expertiza'},
        contributor_id: 1
      }
    end

    context 'when team_user does not exist' do
      it 'shows an error message and redirects to review_mapping#list_mappings page' do
        allow(TeamsUser).to receive(:exists?).with(team_id: '1', user_id: 1).and_return(true)
        post :add_reviewer, @params
        expect(response).to redirect_to '/review_mapping/list_mappings?id=1'
      end
    end

    context 'when team_user exists and get_reviewer method returns a reviewer' do
      it 'creates a whole bunch of objects and redirects to review_mapping#list_mappings page' do
        allow(TeamsUser).to receive(:exists?).with(team_id: '1', user_id: 1).and_return(false)
        allow(SignUpSheet).to receive(:signup_team).with(1, 1, '1').and_return(true)
        user = double('User', id: 1)
        allow(User).to receive(:from_params).with(any_args).and_return(user)
        allow(AssignmentParticipant).to receive(:where).with(user_id: 1, parent_id: 1)
                                                       .and_return([double('AssignmentParticipant', id: 1, name: 'no one')])
        allow(ReviewResponseMap).to receive_message_chain(:where, :first)
          .with(reviewee_id: '1', reviewer_id: 1).with(no_args).and_return(nil)
        allow(ReviewResponseMap).to receive(:create).with(reviewee_id: '1', course_staff: true, reviewed_object_id: 1).and_return(nil)
        post :add_reviewer, @params
        expect(response).to redirect_to '/review_mapping/list_mappings?id=1&msg='
      end
    end
  end

  describe '#assign_reviewer_dynamically' do
    before(:each) do
      allow(AssignmentParticipant).to receive_message_chain(:where, :first)
        .with(user_id: '1', parent_id: 1).with(no_args).and_return(participant)
    end
    context 'when assignment has topics and no topic is selected by reviewer' do
      it 'shows an error message and redirects to student_review#list page' do
        allow(assignment).to receive(:topics?).and_return(true)
        allow(assignment).to receive(:can_choose_topic_to_review?).and_return(true)
        params = {
          assignment_id: 1,
          reviewer_id: 1
        }
        post :assign_reviewer_dynamically, params
        expect(flash[:error]).to eq('No topic is selected.  Please go back and select a topic.')
        expect(response).to redirect_to '/student_review/list?id=1'
      end
    end

    context 'when assignment has topics and a topic is selected by reviewer' do
      it 'assigns reviewer dynamically and redirects to student_review#list page' do
        allow(assignment).to receive(:topics?).and_return(true)
        topic = double('SignUpTopic')
        allow(SignUpTopic).to receive(:find).with('1').and_return(topic)
        allow(assignment).to receive(:assign_reviewer_dynamically).with(participant, topic).and_return(true)
        params = {
          assignment_id: 1,
          reviewer_id: 1,
          topic_id: 1
        }
        post :assign_reviewer_dynamically, params
        expect(response).to redirect_to '/student_review/list?id=1'
      end
    end

    context 'when assignment does not have topics' do
      it 'runs another algorithms and redirects to student_review#list page' do
        allow(assignment).to receive(:topics?).and_return(false)
        team1 = double('AssignmentTeam')
        team2 = double('AssignmentTeam')
        teams = [team1, team2]
        allow(assignment).to receive(:candidate_assignment_teams_to_review).with(participant).and_return(teams)
        allow(teams).to receive_message_chain(:to_a, :sample).and_return(team2)
        allow(assignment).to receive(:assign_reviewer_dynamically_no_topic).with(participant, team2).and_return(true)
        params = {
          assignment_id: 1,
          reviewer_id: 1,
          topic_id: 1
        }
        post :assign_reviewer_dynamically, params
        expect(response).to redirect_to '/student_review/list?id=1'
      end
    end
  end

  describe '#assign_quiz_dynamically' do
    before(:each) do
      allow(AssignmentParticipant).to receive_message_chain(:where, :first)
        .with(user_id: '1', parent_id: 1).with(no_args).and_return(participant)
      @params = {
        assignment_id: 1,
        reviewer_id: 1,
        questionnaire_id: 1,
        participant_id: 1
      }
    end

    context 'when corresponding response map exists' do
      it 'shows a flash error and redirects to student_quizzes page' do
        allow(ResponseMap).to receive_message_chain(:where, :first).with(reviewed_object_id: '1', reviewer_id: '1')
          .with(no_args).and_return(double('ResponseMap'))

        post :assign_quiz_dynamically, @params
        expect(flash[:error]).to eq('You have already taken that quiz.')
        expect(response).to redirect_to('/student_quizzes?id=1')
      end
    end

    context 'when corresponding response map does not exist' do
      it 'creates a new QuizResponseMap and redirects to student_quizzes page' do
        questionnaire = double('Questionnaire', id: 1, instructor_id: 1)
        allow(Questionnaire).to receive(:find).with('1').and_return(questionnaire)
        allow(Questionnaire).to receive(:find_by).with(instructor_id: 1).and_return(questionnaire)
        allow_any_instance_of(QuizResponseMap).to receive(:save).and_return(true)
        post :assign_quiz_dynamically, @params
        expect(flash[:error]).to be nil
        expect(response).to redirect_to('/student_quizzes?id=1')
      end
    end
  end

  describe '#add_metareviewer' do
    before(:each) do
      allow(ResponseMap).to receive(:find).with('1').and_return(review_response_map)
    end

    it 'redirects to review_mapping#list_mappings page' do
      user = double('User', id: 1, name: 'no one')
      allow(User).to receive(:from_params).with(any_args).and_return(user)
      # allow_any_instance_of(ReviewMappingController).to receive(:url_for).with(action: 'add_user_to_assignment', id: 1, user_id: 1).and_return('')
      allow_any_instance_of(ReviewMappingController).to receive(:get_reviewer)
        .with(user, assignment, 'http://test.host/review_mapping/add_user_to_assignment?id=1&user_id=1')
        .and_return(double('AssignmentParticipant', id: 1, name: 'no one'))
      allow(ReviewResponseMap).to receive(:where).with(reviewed_object_id: 1, reviewer_id: 1).and_return([nil])
      params = {id: 1}
      post :add_metareviewer, params
      expect(response).to redirect_to('/review_mapping/list_mappings?id=1&msg=')
    end
  end

  describe '#assign_metareviewer_dynamically' do
    it 'redirects to student_review#list page' do
      metareviewer = double('AssignmentParticipant', id: 1)
      allow(AssignmentParticipant).to receive(:where).with(user_id: '1', parent_id: 1).and_return([metareviewer])
      allow(assignment).to receive(:assign_metareviewer_dynamically).with(metareviewer).and_return(true)
      params = {
        assignment_id: 1,
        metareviewer_id: 1
      }
      post :assign_metareviewer_dynamically, params
      expect(response).to redirect_to('/student_review/list?id=1')
    end
  end

  describe '#delete_outstanding_reviewers' do
    before(:each) do
      allow(AssignmentTeam).to receive(:find).with('1').and_return(team)
      allow(team).to receive(:review_mappings).and_return([double('ReviewResponseMap', id: 1)])
    end

    context 'when review response map has corresponding responses' do
      it 'shows a flash error and redirects to review_mapping#list_mappings page' do
        allow(Response).to receive(:exists?).with(map_id: 1).and_return(true)
        params = {
          id: 1,
          contributor_id: 1
        }
        post :delete_outstanding_reviewers, params
        expect(flash[:success]).to be nil
        expect(flash[:error]).to eq('1 reviewer(s) cannot be deleted because they have already started a review.')
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end

    context 'when review response map does not have corresponding responses' do
      it 'shows a flash success and redirects to review_mapping#list_mappings page' do
        allow(Response).to receive(:exists?).with(map_id: 1).and_return(false)
        review_response_map = double('ReviewResponseMap')
        allow(ReviewResponseMap).to receive(:find).with(1).and_return(review_response_map)
        allow(review_response_map).to receive(:destroy).and_return(true)
        params = {
          id: 1,
          contributor_id: 1
        }
        post :delete_outstanding_reviewers, params
        expect(flash[:error]).to be nil
        expect(flash[:success]).to eq('All review mappings for "no one" have been deleted.')
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end
  end

  describe '#delete_all_metareviewers' do
    before(:each) do
      allow(ResponseMap).to receive(:find).with('1').and_return(review_response_map)
      @metareview_response_maps = [metareview_response_map]
      allow(MetareviewResponseMap).to receive(:where).with(reviewed_object_id: 1).and_return(@metareview_response_maps)
    end

    context 'when failed times are bigger than 0' do
      it 'shows an error flash message and redirects to review_mapping#list_mappings page' do
        allow(ResponseMap).to receive(:delete_mappings).with(@metareview_response_maps, true).and_return(5)
        params = {id: 1, force: true}
        post :delete_all_metareviewers, params
        expect(flash[:note]).to be nil
        expect(flash[:error]).to eq("A delete action failed:<br/>5 metareviews exist for these mappings. "\
          "Delete these mappings anyway?&nbsp;<a href='http://test.host/review_mapping/delete_all_metareviewers?force=1&id=1'>Yes</a>&nbsp;|&nbsp;"\
          "<a href='http://test.host/review_mapping/delete_all_metareviewers?id=1'>No</a><BR/>")
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end

    context 'when failed time is equal to 0' do
      it 'shows a note flash message and redirects to review_mapping#list_mappings page' do
        allow(ResponseMap).to receive(:delete_mappings).with(@metareview_response_maps, true).and_return(0)
        params = {id: 1, force: true}
        post :delete_all_metareviewers, params
        expect(flash[:error]).to be nil
        expect(flash[:note]).to eq('All metareview mappings for contributor "reviewee" and reviewer "reviewer" have been deleted.')
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end
  end

  describe '#unsubmit_review' do
    let(:review_response) { double('Response') }
    before(:each) do
      allow(Response).to receive(:where).with(map_id: '1').and_return([review_response])
      allow(ReviewResponseMap).to receive(:find_by).with(id: '1').and_return(review_response_map)
    end

    context 'when attributes of response are updated successfully' do
      it 'shows a success flash.now message and renders a .js.erb file' do
        allow(review_response).to receive(:update_attribute).with('is_submitted', false).and_return(true)
        params = {id: 1}
        # xhr - XmlHttpRequest (AJAX)
        xhr :get, :unsubmit_review, params
        expect(flash.now[:error]).to be nil
        expect(flash.now[:success]).to eq('The review by "reviewer" for "reviewee" has been unsubmitted.')
        expect(response).to render_template('unsubmit_review.js.erb')
      end
    end

    context 'when attributes of response are not updated successfully' do
      it 'shows an error flash.now message and renders a .js.erb file' do
        allow(review_response).to receive(:update_attribute).with('is_submitted', false).and_return(false)
        params = {id: 1}
        # xhr - XmlHttpRequest (AJAX)
        xhr :get, :unsubmit_review, params
        expect(flash.now[:success]).to be nil
        expect(flash.now[:error]).to eq('The review by "reviewer" for "reviewee" could not be unsubmitted.')
        expect(response).to render_template('unsubmit_review.js.erb')
      end
    end
  end

  describe '#delete_reviewer' do
    before(:each) do
      allow(ReviewResponseMap).to receive(:find_by).with(id: '1').and_return(review_response_map)
      request.env['HTTP_REFERER'] = 'www.google.com'
    end

    context 'when corresponding response does not exist to current review response map' do
      it 'shows a success flash message and redirects to previous page' do
        allow(Response).to receive(:exists?).with(map_id: 1).and_return(false)
        allow(review_response_map).to receive(:destroy).and_return(true)
        params = {id: 1}
        post :delete_reviewer, params
        expect(flash[:success]).to eq('The review mapping for "reviewee" and "reviewer" has been deleted.')
        expect(flash[:error]).to be nil
        expect(response).to redirect_to('www.google.com')
      end
    end

    context 'when corresponding response exists to current review response map' do
      it 'shows an error flash message and redirects to previous page' do
        allow(Response).to receive(:exists?).with(map_id: 1).and_return(true)
        params = {id: 1}
        post :delete_reviewer, params
        expect(flash[:error]).to eq('This review has already been done. It cannot been deleted.')
        expect(flash[:success]).to be nil
        expect(response).to redirect_to('www.google.com')
      end
    end
  end

  describe '#delete_metareviewer' do
    before(:each) do
      allow(MetareviewResponseMap).to receive(:find).with('1').and_return(metareview_response_map)
    end

    context 'when metareview_response_map can be deleted successfully' do
      it 'show a note flash message and redirects to review_mapping#list_mappings page' do
        allow(metareview_response_map).to receive(:delete).and_return(true)
        params = {id: 1}
        post :delete_metareviewer, params
        expect(flash[:note]).to eq('The metareview mapping for reviewee and reviewer has been deleted.')
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end

    context 'when metareview_response_map cannot be deleted successfully' do
      it 'show a note flash message and redirects to review_mapping#list_mappings page' do
        allow(metareview_response_map).to receive(:delete).and_raise('Boom')
        params = {id: 1}
        post :delete_metareviewer, params
        expect(flash[:error]).to eq("A delete action failed:<br/>Boom<a href='/review_mapping/delete_metareview/1'>Delete this mapping anyway>?")
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end
  end
  describe '#select_reviewer' do
    it 'sets the contributor in session variable' do
      allow(AssignmentTeam).to receive(:find).with('1').and_return(team)
      params = { contributor_id: 1 }
      post :select_reviewer, params
      expect(session[:contributor]).to eql(team)
    end
  end

  describe '#select_metareviewer' do
    it 'maps the response to its reviewer' do
      allow(ResponseMap).to receive(:find).with('1').and_return(map)
      params = {id: 1}
      post :select_metareviewer, params
      expect(assigns(:mapping)).to eql(map)
    end
  end

  describe '#add_instructor_as_reviewer' do
    context 'when there is no response map and no reviewer' do
      it 'add instructor as a reviwer and assigns the team a reviwer' do
        params = { team_id: 1, reviewer_id: 1, assignment_id: 1}
        allow(AssignmentTeam).to receive(:find).with('1').and_return(team)
        allow(ReviewResponseMap).to receive_message_chain(:where, :first).with(reviewee_id: 1, course_staff: true, reviewed_object_id: '1').with(no_args).and_return(nil)
        allow(AssignmentParticipant).to receive_message_chain(:where, :first).with(user_id: '1', parent_id: 1).with(no_args).and_return(nil)
        session = {user: build(:instructor, id: 1)}
        allow(AssignmentParticipant).to receive(:create).with(parent_id: 1, user_id: 1, can_submit:false, can_review: true, can_take_quiz: false, handle: 'handle').and_return(reviewer)
        allow(team).to receive(:assign_reviewer).with(reviewer).and_return(review_map)
        post :add_instructor_as_reviewer, params, session
        expect(assigns(:review_map_id)).to eql(review_map)
        expect(response).to redirect_to('/response/new?id=1')
      end
    end
    context 'when there is a reviewer' do
      it 'maps the response and team' do
        allow(AssignmentTeam).to receive(:find).with('1').and_return(team)
        allow(AssignmentParticipant).to receive_message_chain(:where,:first).with(user_id: '1', parent_id: 1).with(no_args).and_return(reviewer)
        allow(ReviewResponseMap).to receive_message_chain(:where, :first).with(reviewee_id: 1, reviewer_id: 1, reviewed_object_id: '1').with(no_args).and_return(review_map)
        session = {user: build(:instructor, id: 1)}
        params = { team_id: 1, reviewer_id: 1, assignment_id: 1}
        post :add_instructor_as_reviewer, params, session
        expect(assigns(:review_map_id)).to eql(review_map)
        expect(response).to redirect_to('/response/new?id=1')
      end
    end
 end

  describe '#delete_metareview' do
    it 'redirects to review_mapping#list_mappings page after deletion' do
      allow(MetareviewResponseMap).to receive(:find).with('1').and_return(metareview_response_map)
      allow(metareview_response_map).to receive(:delete).and_return(true)
      params = {id: 1}
      post :delete_metareview, params
      expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
    end
  end

  describe '#list_mappings' do
    it 'renders review_mapping#list_mappings page' do
      allow(AssignmentTeam).to receive(:where).with(parent_id: 1).and_return([team, team1])
      params = {
        id: 1,
        msg: 'No error!'
      }
      get :list_mappings, params
      expect(flash[:error]).to eq('No error!')
      expect(response).to render_template(:list_mappings)
    end
  end

  describe '#automatic_review_mapping' do
    before(:each) do
      allow(AssignmentParticipant).to receive(:where).with(parent_id: 1).and_return([participant, participant1, participant2])
    end

    context 'when teams is not empty' do
      before(:each) do
        allow(AssignmentTeam).to receive(:where).with(parent_id: 1).and_return([team, team1])
      end

      context 'when all nums in params are 0' do
        it 'shows an error flash message and redirects to review_mapping#list_mappings page' do
          params = {
            id: 1,
            max_team_size: 1,
            num_reviews_per_student: 0,
            num_reviews_per_submission: 0,
            num_calibrated_artifacts: 0,
            num_uncalibrated_artifacts: 0
          }
          post :automatic_review_mapping, params
          expect(flash[:error]).to eq('Please choose either the number of reviews per student or the number of reviewers per team (student).')
          expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
        end
      end

      context 'when all nums in params are 0 except student_review_num' do
        it 'runs automatic review mapping strategy and redirects to review_mapping#list_mappings page' do
          allow_any_instance_of(ReviewMappingController).to receive(:automatic_review_mapping_strategy).with(any_args).and_return(true)
          params = {
            id: 1,
            max_team_size: 1,
            num_reviews_per_student: 1,
            num_reviews_per_submission: 0,
            num_calibrated_artifacts: 0,
            num_uncalibrated_artifacts: 0
          }
          post :automatic_review_mapping, params
          expect(flash[:error]).to be nil
          expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
        end
      end

      context 'when calibrated params are not 0' do
        it 'runs automatic review mapping strategy and redirects to review_mapping#list_mappings page' do
          allow(ReviewResponseMap).to receive(:where).with(reviewed_object_id: 1, calibrate_to: 1)
                                                     .and_return([double('ReviewResponseMap', reviewee_id: 2)])
          allow(AssignmentTeam).to receive(:find).with(2).and_return(team)
          allow_any_instance_of(ReviewMappingController).to receive(:automatic_review_mapping_strategy).with(any_args).and_return(true)
          params = {
            id: 1,
            max_team_size: 1,
            num_reviews_per_student: 1,
            num_reviews_per_submission: 0,
            num_calibrated_artifacts: 1,
            num_uncalibrated_artifacts: 1
          }
          post :automatic_review_mapping, params
          expect(flash[:error]).to be nil
          expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
        end
      end
    end

    context 'when teams is empty, max team size is 1 and when review params are not 0' do
      it 'shows an error flash message and redirects to review_mapping#list_mappings page' do
        allow(TeamsUser).to receive(:team_id).with(1, 2).and_return(true)
        allow(TeamsUser).to receive(:team_id).with(1, 3).and_return(false)
        allow(AssignmentTeam).to receive(:create_team_and_node).with(1).and_return(double('AssignmentTeam', id: 1))
        allow(ApplicationController).to receive_message_chain(:helpers, :create_team_users).with(no_args).with(user, 1).and_return(true)
        params = {
          id: 1,
          max_team_size: 1,
          num_reviews_per_student: 1,
          num_reviews_per_submission: 4,
          num_calibrated_artifacts: 0,
          num_uncalibrated_artifacts: 0
        }
        post :automatic_review_mapping, params
        expect(flash[:error]).to eq('Please choose either the number of reviews per student or the number of reviewers per team (student), not both.')
        expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
      end
    end
  end

  describe '#automatic_review_mapping_staggered' do
    it 'shows a note flash message and redirects to review_mapping#list_mappings page' do
      allow(assignment).to receive(:assign_reviewers_staggered).with('4', '2').and_return('Awesome!')
      params = {
        id: 1,
        assignment: {
          num_reviews: 4,
          num_metareviews: 2
        }
      }
      post :automatic_review_mapping_staggered, params
      expect(flash[:note]).to eq('Awesome!')
      expect(response).to redirect_to('/review_mapping/list_mappings?id=1')
    end
  end

  describe 'response_report' do
    before(:each) do
      stub_const('WEBSERVICE_CONFIG', 'summary_webservice_url' => 'expertiza.ncsu.edu')
    end

    context 'when type is SummaryByRevieweeAndCriteria' do
      it 'renders response_report page with corresponding data' do
        allow(SummaryHelper::Summary).to receive_message_chain(:new, :summarize_reviews_by_reviewees)
          .with(no_args).with(assignment, 'expertiza.ncsu.edu')
          .and_return(double('Summary', summary: 'awesome!', reviewers: [participant, participant1],
                                        avg_scores_by_reviewee: 95, avg_scores_by_round: 92, avg_scores_by_criterion: 94))
        params = {
          id: 1,
          report: {type: 'SummaryByRevieweeAndCriteria'}
        }
        get :response_report, params
        expect(response).to render_template(:response_report)
      end
    end

    context 'when type is SummaryByCriteria' do
      it 'renders response_report page with corresponding data' do
        allow(SummaryHelper::Summary).to receive_message_chain(:new, :summarize_reviews_by_criterion)
          .with(no_args).with(assignment, 'expertiza.ncsu.edu')
          .and_return(double('Summary', summary: 'awesome!', reviewers: [participant, participant1],
                                        avg_scores_by_reviewee: 95, avg_scores_by_round: 92, avg_scores_by_criterion: 94))
        params = {
          id: 1,
          report: {type: 'SummaryByCriteria'}
        }
        get :response_report, params
        expect(response).to render_template(:response_report)
      end
    end

    context 'when type is ReviewResponseMap' do
      it 'renders response_report page with corresponding data' do
        allow(ReviewResponseMap).to receive(:review_response_report).with('1', assignment, 'ReviewResponseMap', 'no one')
                                                                    .and_return([participant, participant1])
        allow(assignment).to receive(:compute_reviews_hash).and_return('1' => 'good')
        allow(assignment).to receive(:compute_avg_and_ranges_hash).and_return(avg: 94, range: [90, 99])
        params = {
          id: 1,
          report: {type: 'ReviewResponseMap'},
          user: 'no one'
        }
        get :response_report, params
        expect(response).to render_template(:response_report)
      end
    end

    context 'when type is FeedbackResponseMap' do
      context 'when assignment has varying_rubrics_by_round feature' do
        it 'renders response_report page with corresponding data' do
          allow(assignment).to receive(:varying_rubrics_by_round?).and_return(true)
          allow(FeedbackResponseMap).to receive(:feedback_response_report).with('1', 'FeedbackResponseMap')
                                                                          .and_return([participant, participant1], [1, 2], [3, 4], [])
          params = {
            id: 1,
            report: {type: 'FeedbackResponseMap'}
          }
          get :response_report, params
          expect(response).to render_template(:response_report)
        end
      end

      context 'when assignment does not have varying_rubrics_by_round feature' do
        it 'renders response_report page with corresponding data' do
          allow(assignment).to receive(:varying_rubrics_by_round?).and_return(false)
          allow(FeedbackResponseMap).to receive(:feedback_response_report).with('1', 'FeedbackResponseMap')
                                                                          .and_return([participant, participant1], [1, 2, 3, 4])
          params = {
            id: 1,
            report: {type: 'FeedbackResponseMap'}
          }
          get :response_report, params
          expect(response).to render_template(:response_report)
        end
      end
    end

    context 'when type is TeammateReviewResponseMap' do
      it 'renders response_report page with corresponding data' do
        allow(TeammateReviewResponseMap).to receive(:teammate_response_report).with('1').and_return([participant, participant2])
        params = {
          id: 1,
          report: {type: 'TeammateReviewResponseMap'}
        }
        get :response_report, params
        expect(response).to render_template(:response_report)
      end
    end

    context 'when type is Calibration and participant variable is nil' do
      it 'renders response_report page with corresponding data' do
        allow(AssignmentParticipant).to receive(:where).with(parent_id: '1', user_id: 3).and_return([nil])
        allow(AssignmentParticipant).to receive(:create)
          .with(parent_id: '1', user_id: 3, can_submit: 1, can_review: 1, can_take_quiz: 1, handle: 'handle').and_return(participant)
        allow(ReviewQuestionnaire).to receive(:select).with('id').and_return([1, 2, 3])
        assignment_questionnaire = double('AssignmentQuestionnaire')
        allow(AssignmentQuestionnaire).to receive(:where).with(assignment_id: '1', questionnaire_id: [1, 2, 3])
                                                         .and_return([assignment_questionnaire])
        allow(assignment_questionnaire).to receive_message_chain(:questionnaire, :questions).and_return([double('Question', type: 'Criterion')])
        allow(ReviewResponseMap).to receive(:where).with(reviewed_object_id: '1', calibrate_to: 1).and_return([review_response_map])
        allow(ReviewResponseMap).to receive_message_chain(:select, :where).with('id').with(reviewed_object_id: '1', calibrate_to: 0)
                                                                          .and_return([1, 2])
        allow(Response).to receive(:where).with(map_id: [1, 2]).and_return([double('response')])
        params = {
          id: 1,
          report: {type: 'Calibration'}
        }
        session = {user: user}
        get :response_report, params, session
        expect(response).to render_template(:response_report)
      end
    end

    context 'when type is PlagiarismCheckerReport' do
      it 'renders response_report page with corresponding data' do
        allow(PlagiarismCheckerAssignmentSubmission).to receive_message_chain(:where, :pluck).with(assignment_id: '1').with(:id)
                                                                                             .and_return([double('PlagiarismCheckerAssignmentSubmission', id: 1)])
        allow(PlagiarismCheckerAssignmentSubmission).to receive(:where).with(plagiarism_checker_assignment_submission_id: 1)
                                                                       .and_return([double('PlagiarismCheckerAssignmentSubmission')])
        params = {
          id: 1,
          report: {type: 'PlagiarismCheckerReport'}
        }
        get :response_report, params
        expect(response).to render_template(:response_report)
      end
    end
  end

  describe '#save_grade_and_comment_for_reviewer' do
    it 'redirects to review_mapping#response_report page' do
      review_grade = build(:review_grade)
      allow(ReviewGrade).to receive(:find_by).with(participant_id: '1').and_return(review_grade)
      allow(review_grade).to receive(:save).and_return(true)
      params = {
        participant_id: 1,
        grade_for_reviewer: 90,
        comment_for_reviewer: 'keke'
      }
      session = {user: double('User', id: 1)}
      post :save_grade_and_comment_for_reviewer, params, session
      expect(flash[:note]).to be nil
      expect(response).to redirect_to('/review_mapping/response_report')
    end
  end

  describe '#start_self_review' do
    before(:each) do
      allow(TeamsUser).to receive(:find_by_sql).with(
        ["SELECT t.id as t_id FROM teams_users u, teams t WHERE u.team_id = t.id and t.parent_id = ? and user_id = ?", 1, '1']
      )
                                               .and_return([double('TeamsUser', t_id: 1)])
    end

    context 'when self review response map does not exist' do
      it 'creates a new record and redirects to submitted_content#edit page' do
        allow(SelfReviewResponseMap).to receive(:where).with(reviewee_id: 1, reviewer_id: '1').and_return([nil])
        allow(SelfReviewResponseMap).to receive(:create).with(reviewee_id: 1, reviewer_id: '1', reviewed_object_id: 1).and_return(true)
        params = {
          assignment_id: 1,
          reviewer_userid: 1,
          reviewer_id: 1
        }
        post :start_self_review, params
        expect(response).to redirect_to('/submitted_content/1/edit')
      end
    end

    context 'when self review response map exists' do
      it 'redirects to submitted_content#edit page' do
        allow(SelfReviewResponseMap).to receive(:where).with(reviewee_id: 1, reviewer_id: '1').and_return([double('SelfReviewResponseMap')])
        params = {
          assignment_id: 1,
          reviewer_userid: 1,
          reviewer_id: 1
        }
        post :start_self_review, params
        expect(response).to redirect_to('/submitted_content/1/edit?msg=Self+review+already+assigned%21')
      end
    end
  end
end
