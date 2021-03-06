function main_tlqg
    close all;
    params=setParams;
    t=1;
    mean_curr(:,t)=params.mean_init;
    cov_curr(t)=params.cov_init;
    mean_traj=mean_curr;
    cov_traj=cov_curr;
    [mean_des,ctrl_des]=createPlan(mean_curr(:,t),cov_curr(t),params);
    cov_des=calculateCov(mean_curr(:,t),cov_curr(t),mean_des,params);
    [~,params.goal_thresh]=isGoalReached(mean_des(:,params.time.N),cov_des(params.time.N),params);
    params.goal_thresh=0.5;
    draw_plan(mean_des,cov_des,ctrl_des,params);
    replan_count=0;
    continue_run=1;
    v=VideoWriter('myFile.avi');
    open(v);
    F=getframe(figure(1));
    writeVideo(v,F.cdata);
    while(~isGoalReached(mean_curr(:,t),cov_curr(t),params) && continue_run)
        replan_count=replan_count+1;
        for t=1:params.time.N-1
            state_pred=mean_curr(:,t);
            state_des=mean_des(:,t);
            linear_fb_gain=solveLQR(params);
            
            ctrl(:,t)=ctrl_des(:,t)-linear_fb_gain(:,:,t)*(state_pred-state_des);
            if (ctrl(:,t)>params.domain.ctrl_max)
                ctrl(:,t)=params.domain.ctrl_max;
            elseif (ctrl(:,t)<-1*params.domain.ctrl_max)
                ctrl(:,t)=-1*params.domain.ctrl_max;
            end
            % noisy execution
            state_next_pred=processDynamics(state_pred,ctrl(:,t),params,'Noise');
            % noisy observation
            y=repmat((-1+2*rand(1))*obsNoiseCov(state_next_pred),params.num_ctrl,1);
            % estimation with EKF    
            [mean_curr(:,t+1),cov_curr(t+1)]= ekf(mean_curr(:,t),cov_curr(t),ctrl(:,t),y,params);
            if (klDivergence(mean_curr(:,t+1),cov_curr(t+1),mean_des(:,t+1),cov_des(:,t+1),params)>params.replan_thresh) ...
                    || (t+1==params.time.N && ~isGoalReached(mean_curr(:,t+1),cov_curr(t+1),params))
                params.time.N=params.time.N-t;
                params.time.T=(params.time.N-1)*params.time.dt;
                [mean_des,ctrl_des,ef]=createPlan(mean_curr(:,t+1),cov_curr(t+1),params);
                cov_des=calculateCov(mean_curr(:,t+1),cov_curr(t+1),mean_des,params);
                mean_traj(:,end+1)=mean_curr(:,t+1);
                cov_traj(end+1)=cov_curr(t+1);
                figure(1);
                subplot(3,4,[1 2 3 5 6 7 9 10 11]);
                hold on;
                x = linspace(-2.5,10,100);
                z = obsNoiseCov(x);
%                 plot3(mean_curr(1,t+1),mean_curr(2,t+1),max(z),'ro','MarkerSize',10,'MarkerFaceColor','r');
                plot3(mean_traj(1,:),mean_traj(2,:),repmat(max(z),size(mean_traj,2),1),'g','LineWidth',2,'HandleVisibility','off');
                plot3(mean_des(1,:),mean_des(2,:),repmat(max(z),size(mean_des,2),1),'k','LineWidth',2,'DisplayName','re-plan');
                drawnow;
                F(end+1)=getframe(figure(1));
                writeVideo(v,F(end).cdata);
                if(ef==-2 && (norm(mean_des(:,end)-params.b_goal)>0.5 || params.time.N==1))
                    fprintf('infeasible trajectory, so break and plot whatever you have \n');
                    continue_run=0;
                    break;
                end
                if (ef~=1 && ef~=2 && ef~=-2)
                    fprintf('infeasible trajectory, so break and plot whatever you have \n');
                    continue_run=0;
                    break;
                end
                mean_curr=mean_curr(:,t+1);
                cov_curr=cov_curr(t+1);
                t=1;
                break;
            else
                mean_traj(:,end+1)=mean_curr(:,t+1);
                cov_traj(end+1)=cov_curr(t+1);
                figure(1);
                subplot(3,4,[1 2 3 5 6 7 9 10 11]);
                hold on;
                x = linspace(-2.5,10,100);
                z = obsNoiseCov(x);
%                 plot3(mean_curr(1,t+1),mean_curr(2,t+1),max(z),'ro','MarkerSize',10,'MarkerFaceColor','r');
                plot3(mean_traj(1,:),mean_traj(2,:),repmat(max(z),size(mean_traj,2),1),'g','LineWidth',2,'HandleVisibility','off');
                drawnow;
                F(end+1)=getframe(figure(1));
                writeVideo(v,F(end).cdata);
                if (t+1==params.time.N)
                    t=t+1;
                    fprintf('followed till the end\n');
                end
            end
        end
    end
    figure(1);
    subplot(3,4,8);
    hold on;
    x = linspace(-2.5,10,100);
    z = obsNoiseCov(x);
    time=0:params.time.dt:(length(cov_traj)-1)*params.time.dt;
    plot(time,cov_traj,'LineWidth',2,'DisplayName','robot cov');
    drawnow;
    F(end+1)=getframe(figure(1));
    writeVideo(v,F(end).cdata);
    close(v);
end