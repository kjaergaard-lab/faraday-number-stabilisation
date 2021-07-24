classdef AppFeedbackDP_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        TabGroup                        matlab.ui.container.TabGroup
        SettingsTab                     matlab.ui.container.Tab
        EnableDispersivePulsesCheckBox  matlab.ui.control.CheckBox
        EnableFeedbackCheckBox          matlab.ui.control.CheckBox
        UseManualMWPulsesCheckBox       matlab.ui.control.CheckBox
        DispersivePulseSettingsPanel    matlab.ui.container.Panel
        PulseWidthsEditFieldLabel       matlab.ui.control.Label
        PulseWidthsEditField            matlab.ui.control.NumericEditField
        PulsePeriodsEditFieldLabel      matlab.ui.control.Label
        PulsePeriodsEditField           matlab.ui.control.NumericEditField
        AuxDelaysEditFieldLabel         matlab.ui.control.Label
        AuxDelaysEditField              matlab.ui.control.NumericEditField
        ShutterDelaysEditFieldLabel     matlab.ui.control.Label
        ShutterDelaysEditField          matlab.ui.control.NumericEditField
        NumberofPulsesSpinnerLabel      matlab.ui.control.Label
        NumberofPulsesSpinner           matlab.ui.control.Spinner
        SamplingSettingsPanel           matlab.ui.container.Panel
        SignalAcqDelaysEditFieldLabel   matlab.ui.control.Label
        SignalAcqDelaysEditField        matlab.ui.control.NumericEditField
        SamplesPerPulseSpinnerLabel     matlab.ui.control.Label
        SamplesPerPulseSpinner          matlab.ui.control.Spinner
        Log2OfAvgsSpinnerLabel          matlab.ui.control.Label
        Log2OfAvgsSpinner               matlab.ui.control.Spinner
        StartofSummationSpinnerLabel    matlab.ui.control.Label
        StartofSummationSpinner         matlab.ui.control.Spinner
        StartofSubractionSpinnerLabel   matlab.ui.control.Label
        StartofSubractionSpinner        matlab.ui.control.Spinner
        SumSubwidthSpinnerLabel         matlab.ui.control.Label
        SumSubwidthSpinner              matlab.ui.control.Spinner
        Offset1EditFieldLabel           matlab.ui.control.Label
        Offset1EditField                matlab.ui.control.NumericEditField
        Offset2EditFieldLabel           matlab.ui.control.Label
        Offset2EditField                matlab.ui.control.NumericEditField
        UsePresetOffsetsCheckBox        matlab.ui.control.CheckBox
        AuxAcqDelaysEditFieldLabel      matlab.ui.control.Label
        AuxAcqDelaysEditField           matlab.ui.control.NumericEditField
        FeedbackSettingsPanel           matlab.ui.container.Panel
        MaxMWPulsesEditFieldLabel       matlab.ui.control.Label
        MaxMWPulsesEditField            matlab.ui.control.NumericEditField
        TargetSignalEditFieldLabel      matlab.ui.control.Label
        TargetSignalEditField           matlab.ui.control.NumericEditField
        SignalToleranceEditFieldLabel   matlab.ui.control.Label
        SignalToleranceEditField        matlab.ui.control.NumericEditField
        MicrowaveSettingsPanel          matlab.ui.container.Panel
        MWPulseWidthsEditFieldLabel     matlab.ui.control.Label
        MWPulseWidthsEditField          matlab.ui.control.NumericEditField
        MWPulsePeriodsEditFieldLabel    matlab.ui.control.Label
        MWPulsePeriodsEditField         matlab.ui.control.NumericEditField
        ManualMWPulsesSpinnerLabel      matlab.ui.control.Label
        ManualMWPulsesSpinner           matlab.ui.control.Spinner
        FetchSettingsButton             matlab.ui.control.Button
        UploadSettingsButton            matlab.ui.control.Button
        SetDefaultsButton               matlab.ui.control.Button
        FetchDataButton                 matlab.ui.control.Button
        ReadonlyPanel                   matlab.ui.container.Panel
        NumberofSamplesCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofSamplesCollectedEditField  matlab.ui.control.NumericEditField
        NumberofPulsesCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofPulsesCollectedEditField  matlab.ui.control.NumericEditField
        NumberofAuxPulsesCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofAuxPulsesCollectedEditField  matlab.ui.control.NumericEditField
        NumberofRatiosCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofRatiosCollectedEditField  matlab.ui.control.NumericEditField
        ResetButton                     matlab.ui.control.Button
        StartButton                     matlab.ui.control.Button
        CalculatedValuesPanel           matlab.ui.container.Panel
        EffectivesamplerateHzEditFieldLabel  matlab.ui.control.Label
        EffectivesamplerateHzEditField  matlab.ui.control.NumericEditField
        SamplesPulseWidthEditFieldLabel  matlab.ui.control.Label
        SamplesPulseWidthEditField      matlab.ui.control.NumericEditField
        SamplesPulsePeriodEditFieldLabel  matlab.ui.control.Label
        SamplesPulsePeriodEditField     matlab.ui.control.NumericEditField
        ManualOutputsPanel              matlab.ui.container.Panel
        UseManualValuesButton           matlab.ui.control.StateButton
        DPPulseButton                   matlab.ui.control.StateButton
        ShutterButton                   matlab.ui.control.StateButton
        MWPulseButton                   matlab.ui.control.StateButton
        AuxButton                       matlab.ui.control.StateButton
        SignalcomputationPanel          matlab.ui.container.Panel
        UseFixedAuxValuesCheckBox       matlab.ui.control.CheckBox
        Aux1EditFieldLabel              matlab.ui.control.Label
        Aux1EditField                   matlab.ui.control.NumericEditField
        Aux2EditFieldLabel              matlab.ui.control.Label
        Aux2EditField                   matlab.ui.control.NumericEditField
        ValidationsettingsPanel         matlab.ui.container.Panel
        NumAddPulsesEditFieldLabel      matlab.ui.control.Label
        NumAddPulsesEditField           matlab.ui.control.NumericEditField
        UseAdditionalPulsesCheckBox     matlab.ui.control.CheckBox
        RawDataTab                      matlab.ui.container.Tab
        RawSignalAxes                   matlab.ui.control.UIAxes
        RawAuxAxes                      matlab.ui.control.UIAxes
        SignalTab                       matlab.ui.container.Tab
        IntegratedSignalAxes            matlab.ui.control.UIAxes
        IntegratedAuxAxes               matlab.ui.control.UIAxes
        SumandDifferenceTab             matlab.ui.container.Tab
        SumDiffAxes                     matlab.ui.control.UIAxes
        ComputedDataTab                 matlab.ui.container.Tab
        ComputedDataAxes                matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
    end
    
    properties (Access = public)
        fb      DPFeedback      % DPFeedback Object
    end
    
    methods (Access = private)
        
        function results = updateFields(app)
            app.EnableDispersivePulsesCheckBox.Value = logical(app.fb.enableDP.value);
            app.EnableFeedbackCheckBox.Value = logical(app.fb.enableFB.value);
            app.UseManualMWPulsesCheckBox.Value = logical(app.fb.enableManualMW.value);
            
            app.PulseWidthsEditField.Value = app.fb.width.value;
            app.PulsePeriodsEditField.Value = app.fb.period.value;
            app.NumberofPulsesSpinner.Value = app.fb.numpulses.value;
            app.ShutterDelaysEditField.Value = app.fb.shutterDelay.value;
            app.AuxDelaysEditField.Value = app.fb.auxDelay.value;
            
            app.SignalAcqDelaysEditField.Value = app.fb.delaySignal.value;
            app.AuxAcqDelaysEditField.Value = app.fb.delayAux.value;
            app.SamplesPerPulseSpinner.Value = app.fb.samplesPerPulse.value;
            app.Log2OfAvgsSpinner.Value = app.fb.log2Avgs.value;
            app.StartofSummationSpinner.Value = app.fb.sumStart.value;
            app.StartofSubractionSpinner.Value = app.fb.subStart.value;
            app.SumSubwidthSpinner.Value = app.fb.sumWidth.value;
            app.UsePresetOffsetsCheckBox.Value = logical(app.fb.usePresetOffsets.value);
            app.Offset1EditField.Value = app.fb.offsets(1).value;
            app.Offset2EditField.Value = app.fb.offsets(2).value;
            
            app.UseFixedAuxValuesCheckBox.Value = logical(app.fb.useFixedGain.value);
            app.Aux1EditField.Value = app.fb.fixedAux(1).value;
            app.Aux2EditField.Value = app.fb.fixedAux(2).value;
            
            app.MaxMWPulsesEditField.Value = app.fb.maxMWPulses.value;
            app.TargetSignalEditField.Value = app.fb.target.value;
            app.SignalToleranceEditField.Value = app.fb.tol.value;
            app.ManualMWPulsesSpinner.Value = app.fb.mwNumPulses.value;
            app.MWPulseWidthsEditField.Value = app.fb.mwPulseWidth.value;
            app.MWPulsePeriodsEditField.Value = app.fb.mwPulsePeriod.value;
            
            app.NumAddPulsesEditField.Value = app.fb.additionalPulses.value;
            app.UseAdditionalPulsesCheckBox.Value = logical(app.fb.useAdditionalPulses.value);
            
            
            app.NumberofSamplesCollectedEditField.Value = app.fb.samplesCollected(1).value;
            app.NumberofPulsesCollectedEditField.Value = app.fb.pulsesCollected(1).value;
            app.NumberofAuxPulsesCollectedEditField.Value = app.fb.pulsesCollected(2).value;
            app.NumberofRatiosCollectedEditField.Value = app.fb.pulsesCollected(3).value;
            
            app.EffectivesamplerateHzEditField.Value = app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulsePeriodEditField.Value = app.fb.period.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulseWidthEditField.Value = app.fb.width.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
            
            app.UseManualValuesButton.Value = logical(app.fb.manualFlag.value);
            app.DPPulseButton.Value = logical(app.fb.pulseDPMan.value);
            app.ShutterButton.Value = logical(app.fb.shutterDPMan.value);
            app.MWPulseButton.Value = logical(app.fb.pulseMWMan.value);
            app.AuxButton.Value = logical(app.fb.auxMan.value);
            
            results = 0;
        end
        
        function plotData(app)
            % Raw signal data first
            if app.fb.samplesPerPulse.value <= 100
                xstep = 5;
            elseif app.fb.samplesPerPulse.value <= 300
                xstep = 10;
            elseif app.fb.samplesPerPulse.value <= 500
                xstep = 25;
            else
                xstep = 50;
            end
            cla(app.RawSignalAxes);
            plot(app.RawSignalAxes,1:app.fb.samplesPerPulse.value,app.fb.signal.rawX,'b.-');
            hold(app.RawSignalAxes,'on');
            plot(app.RawSignalAxes,1:app.fb.samplesPerPulse.value,app.fb.signal.rawY,'r.-');
            yy = ylim(app.RawSignalAxes);
            plot(app.RawSignalAxes,app.fb.sumStart.value*[1,1],yy,'k--','linewidth',2);
            plot(app.RawSignalAxes,(app.fb.sumStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
            if ~app.fb.usePresetOffsets.value
                plot(app.RawSignalAxes,app.fb.subStart.value*[1,1],yy,'k--','linewidth',2);
                plot(app.RawSignalAxes,(app.fb.subStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
            end
            hold(app.RawSignalAxes,'off');
            xlabel(app.RawSignalAxes,'Samples');ylabel(app.RawSignalAxes,'Value');
            set(app.RawSignalAxes,'xtick',0:xstep:app.fb.samplesPerPulse.value);
            set(app.RawSignalAxes,'xgrid','on');
            
            % Raw auxiliary data next
            cla(app.RawAuxAxes);
            if ~app.fb.useFixedGain.value
                plot(app.RawAuxAxes,1:app.fb.samplesPerPulse.value,app.fb.aux.rawX,'b.-');
                hold(app.RawAuxAxes,'on');
                plot(app.RawAuxAxes,1:app.fb.samplesPerPulse.value,app.fb.aux.rawY,'r.-');
                yy = ylim(app.RawAuxAxes);
                plot(app.RawAuxAxes,app.fb.sumStart.value*[1,1],yy,'k--','linewidth',2);
                plot(app.RawAuxAxes,(app.fb.sumStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
                if ~app.fb.usePresetOffsets.value
                    plot(app.RawAuxAxes,app.fb.subStart.value*[1,1],yy,'k--','linewidth',2);
                    plot(app.RawAuxAxes,(app.fb.subStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
                end
                hold(app.RawAuxAxes,'off');
            end
            xlabel(app.RawAuxAxes,'Samples');ylabel(app.RawAuxAxes,'Value');
            set(app.RawAuxAxes,'xtick',0:xstep:app.fb.samplesPerPulse.value);
            set(app.RawAuxAxes,'xgrid','on');
            
            % Integrated signal data next
            cla(app.IntegratedSignalAxes);
            plot(app.IntegratedSignalAxes,app.fb.signal.t,app.fb.signal.data,'.-');
            legend(app.IntegratedSignalAxes,'X','Y');
            xlabel(app.IntegratedSignalAxes,'Time [s]');ylabel(app.IntegratedSignalAxes,'Value');
            
            % Integrated aux data next
            cla(app.IntegratedAuxAxes);
            if ~app.fb.useFixedGain.value
                plot(app.IntegratedAuxAxes,app.fb.aux.t,app.fb.aux.data,'.-');
                legend(app.IntegratedAuxAxes,'X','Y');
            end
            xlabel(app.IntegratedAuxAxes,'Time [s]');ylabel(app.IntegratedAuxAxes,'Value');
            
            % Sum and difference signals next
            cla(app.SumDiffAxes);
            plot(app.SumDiffAxes,app.fb.t,[app.fb.diff,app.fb.sum],'.-');
            legend(app.SumDiffAxes,'Difference','Sum');
            xlabel(app.SumDiffAxes,'Time [s]');ylabel(app.SumDiffAxes,'Values');
            
            % Computed data next
            cla(app.ComputedDataAxes)
            plot(app.ComputedDataAxes,app.fb.t,app.fb.ratio,'.-');
            xlabel(app.ComputedDataAxes,'Time [s]');ylabel(app.ComputedDataAxes,'Ratio');
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, fb_in)
            if nargin < 2
                app.fb = DPFeedback;
                app.fb.setDefaults;
            else
                app.fb = fb_in;
            end
            app.updateFields;
        end

        % Value changed function: EnableDispersivePulsesCheckBox
        function EnableDispersivePulsesCheckBoxValueChanged(app, event)
            value = app.EnableDispersivePulsesCheckBox.Value;
            app.fb.enableDP.set(logical(value));
        end

        % Value changed function: EnableFeedbackCheckBox
        function EnableFeedbackCheckBoxValueChanged(app, event)
            value = app.EnableFeedbackCheckBox.Value;
            app.fb.enableFB.set(logical(value));
        end

        % Value changed function: UseManualMWPulsesCheckBox
        function UseManualMWPulsesCheckBoxValueChanged(app, event)
            value = app.UseManualMWPulsesCheckBox.Value;
            app.fb.enableManualMW.set(logical(value));
        end

        % Value changed function: PulseWidthsEditField
        function PulseWidthsEditFieldValueChanged(app, event)
            value = app.PulseWidthsEditField.Value;
            app.fb.width.set(value);
            app.SamplesPulseWidthEditField.Value = app.fb.width.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
        end

        % Value changed function: PulsePeriodsEditField
        function PulsePeriodsEditFieldValueChanged(app, event)
            value = app.PulsePeriodsEditField.Value;
            app.fb.period.set(value);
            app.SamplesPulsePeriodEditField.Value = app.fb.period.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
        end

        % Value changed function: NumberofPulsesSpinner
        function NumberofPulsesSpinnerValueChanged(app, event)
            value = app.NumberofPulsesSpinner.Value;
            app.fb.numpulses.set(value);
        end

        % Value changed function: SignalAcqDelaysEditField
        function SignalAcqDelaysEditFieldValueChanged(app, event)
            value = app.SignalAcqDelaysEditField.Value;
            app.fb.delaySignal.set(value);
        end

        % Value changed function: SamplesPerPulseSpinner
        function SamplesPerPulseSpinnerValueChanged(app, event)
            value = app.SamplesPerPulseSpinner.Value;
            app.fb.samplesPerPulse.set(value);
        end

        % Value changed function: Log2OfAvgsSpinner
        function Log2OfAvgsSpinnerValueChanged(app, event)
            value = app.Log2OfAvgsSpinner.Value;
            app.fb.log2Avgs.set(value);
            app.EffectivesamplerateHzEditField.Value = app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulsePeriodEditField.Value = app.fb.period.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulseWidthEditField.Value = app.fb.width.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
        end

        % Value changed function: StartofSummationSpinner
        function StartofSummationSpinnerValueChanged(app, event)
            value = app.StartofSummationSpinner.Value;
            app.fb.sumStart.set(value);
        end

        % Value changed function: StartofSubractionSpinner
        function StartofSubractionSpinnerValueChanged(app, event)
            value = app.StartofSubractionSpinner.Value;
            app.fb.subStart.set(value);
        end

        % Value changed function: SumSubwidthSpinner
        function SumSubwidthSpinnerValueChanged(app, event)
            value = app.SumSubwidthSpinner.Value;
            app.fb.sumWidth.set(value);
        end

        % Value changed function: MaxMWPulsesEditField
        function MaxMWPulsesEditFieldValueChanged(app, event)
            value = app.MaxMWPulsesEditField.Value;
            app.fb.maxMWPulses.set(value);
        end

        % Value changed function: TargetSignalEditField
        function TargetSignalEditFieldValueChanged(app, event)
            value = app.TargetSignalEditField.Value;
            app.fb.target.set(value);
        end

        % Value changed function: SignalToleranceEditField
        function SignalToleranceEditFieldValueChanged(app, event)
            value = app.SignalToleranceEditField.Value;
            app.fb.tol.set(value);
        end

        % Value changed function: MWPulseWidthsEditField
        function MWPulseWidthsEditFieldValueChanged(app, event)
            value = app.MWPulseWidthsEditField.Value;
            app.fb.mwPulseWidth.set(value);
        end

        % Value changed function: MWPulsePeriodsEditField
        function MWPulsePeriodsEditFieldValueChanged(app, event)
            value = app.MWPulsePeriodsEditField.Value;
            app.fb.mwPulsePeriod.set(value);
        end

        % Value changed function: ManualMWPulsesSpinner
        function ManualMWPulsesSpinnerValueChanged(app, event)
            value = app.ManualMWPulsesSpinner.Value;
            app.fb.mwNumPulses.set(value);
        end

        % Button pushed function: FetchSettingsButton
        function FetchSettingsButtonPushed(app, event)
            app.fb.fetch;          
            app.updateFields;
        end

        % Button pushed function: UploadSettingsButton
        function UploadSettingsButtonPushed(app, event)
            app.fb.upload;
        end

        % Button pushed function: SetDefaultsButton
        function SetDefaultsButtonPushed(app, event)
            app.fb.setDefaults;
            
            app.updateFields;
        end

        % Button pushed function: FetchDataButton
        function FetchDataButtonPushed(app, event)
            app.fb.getRaw.getProcessed;
            app.fb.pulsesCollected(3).read;
            app.updateFields;
            app.fb.calcRatio;
            app.plotData;
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            app.fb.reset;
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            app.fb.start;
        end

        % Value changed function: ShutterDelaysEditField
        function ShutterDelaysEditFieldValueChanged(app, event)
            value = app.ShutterDelaysEditField.Value;
            app.fb.shutterDelay.set(value);
        end

        % Value changed function: UseManualValuesButton
        function UseManualValuesButtonValueChanged(app, event)
            value = app.UseManualValuesButton.Value;
            app.fb.manualFlag.set(value).write;
        end

        % Value changed function: DPPulseButton
        function DPPulseButtonValueChanged(app, event)
            value = app.DPPulseButton.Value;
            app.fb.pulseDPMan.set(value).write;
        end

        % Value changed function: ShutterButton
        function ShutterButtonValueChanged(app, event)
            value = app.ShutterButton.Value;
            app.fb.shutterDPMan.set(value).write;
        end

        % Value changed function: MWPulseButton
        function MWPulseButtonValueChanged(app, event)
            value = app.MWPulseButton.Value;
            app.fb.pulseMWMan.set(value).write;
        end

        % Value changed function: AuxButton
        function AuxButtonValueChanged(app, event)
            value = app.AuxButton.Value;
            app.fb.auxMan.set(value).write;
        end

        % Value changed function: AuxDelaysEditField
        function AuxDelaysEditFieldValueChanged(app, event)
            value = app.AuxDelaysEditField.Value;
            app.fb.auxDelay.set(value);
        end

        % Value changed function: Offset1EditField
        function Offset1EditFieldValueChanged(app, event)
            value = app.Offset1EditField.Value;
            app.fb.offsets(1).set(value);
        end

        % Value changed function: Offset2EditField
        function Offset2EditFieldValueChanged(app, event)
            value = app.Offset2EditField.Value;
            app.fb.offsets(2).set(value);
        end

        % Value changed function: UsePresetOffsetsCheckBox
        function UsePresetOffsetsCheckBoxValueChanged(app, event)
            value = app.UsePresetOffsetsCheckBox.Value;
            app.fb.usePresetOffsets.set(value);
        end

        % Value changed function: UseFixedAuxValuesCheckBox
        function UseFixedAuxValuesCheckBoxValueChanged(app, event)
            value = app.UseFixedAuxValuesCheckBox.Value;
            app.fb.useFixedGain.set(value);
        end

        % Value changed function: Aux1EditField
        function Aux1EditFieldValueChanged(app, event)
            value = app.Aux1EditField.Value;
            app.fb.presetGains(1).set(value);
            
        end

        % Value changed function: Aux2EditField
        function Aux2EditFieldValueChanged(app, event)
            value = app.Aux2EditField.Value;
            app.fb.presetGains(2).set(value);
        end

        % Value changed function: AuxAcqDelaysEditField
        function AuxAcqDelaysEditFieldValueChanged(app, event)
            value = app.AuxAcqDelaysEditField.Value;
            app.fb.delayAux.set(value);
        end

        % Value changed function: UseAdditionalPulsesCheckBox
        function UseAdditionalPulsesCheckBoxValueChanged(app, event)
            value = app.UseAdditionalPulsesCheckBox.Value;
            app.fb.useAdditionalPulses.set(value);
        end

        % Value changed function: NumAddPulsesEditField
        function NumAddPulsesEditFieldValueChanged(app, event)
            value = app.NumAddPulsesEditField.Value;
            app.fb.additionalPulses.set(value);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 863 667];
            app.UIFigure.Name = 'UI Figure';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [1 1 863 667];

            % Create SettingsTab
            app.SettingsTab = uitab(app.TabGroup);
            app.SettingsTab.Title = 'Settings';

            % Create EnableDispersivePulsesCheckBox
            app.EnableDispersivePulsesCheckBox = uicheckbox(app.SettingsTab);
            app.EnableDispersivePulsesCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableDispersivePulsesCheckBoxValueChanged, true);
            app.EnableDispersivePulsesCheckBox.Text = 'Enable Dispersive Pulses';
            app.EnableDispersivePulsesCheckBox.Position = [15 611 185 22];

            % Create EnableFeedbackCheckBox
            app.EnableFeedbackCheckBox = uicheckbox(app.SettingsTab);
            app.EnableFeedbackCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableFeedbackCheckBoxValueChanged, true);
            app.EnableFeedbackCheckBox.Text = 'Enable Feedback';
            app.EnableFeedbackCheckBox.Position = [15 581 115 22];

            % Create UseManualMWPulsesCheckBox
            app.UseManualMWPulsesCheckBox = uicheckbox(app.SettingsTab);
            app.UseManualMWPulsesCheckBox.ValueChangedFcn = createCallbackFcn(app, @UseManualMWPulsesCheckBoxValueChanged, true);
            app.UseManualMWPulsesCheckBox.Text = 'Use Manual MW Pulses';
            app.UseManualMWPulsesCheckBox.Position = [15 554 150 22];

            % Create DispersivePulseSettingsPanel
            app.DispersivePulseSettingsPanel = uipanel(app.SettingsTab);
            app.DispersivePulseSettingsPanel.Title = 'Dispersive Pulse Settings';
            app.DispersivePulseSettingsPanel.Position = [16 355 229 188];

            % Create PulseWidthsEditFieldLabel
            app.PulseWidthsEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.PulseWidthsEditFieldLabel.HorizontalAlignment = 'right';
            app.PulseWidthsEditFieldLabel.Position = [26 140 86 22];
            app.PulseWidthsEditFieldLabel.Text = 'Pulse Width [s]';

            % Create PulseWidthsEditField
            app.PulseWidthsEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.PulseWidthsEditField.ValueChangedFcn = createCallbackFcn(app, @PulseWidthsEditFieldValueChanged, true);
            app.PulseWidthsEditField.Position = [117 140 100 22];

            % Create PulsePeriodsEditFieldLabel
            app.PulsePeriodsEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.PulsePeriodsEditFieldLabel.HorizontalAlignment = 'right';
            app.PulsePeriodsEditFieldLabel.Position = [16 109 90 22];
            app.PulsePeriodsEditFieldLabel.Text = 'Pulse Period [s]';

            % Create PulsePeriodsEditField
            app.PulsePeriodsEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.PulsePeriodsEditField.ValueChangedFcn = createCallbackFcn(app, @PulsePeriodsEditFieldValueChanged, true);
            app.PulsePeriodsEditField.Position = [117 109 100 22];

            % Create AuxDelaysEditFieldLabel
            app.AuxDelaysEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.AuxDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.AuxDelaysEditFieldLabel.Position = [25 9 76 22];
            app.AuxDelaysEditFieldLabel.Text = 'Aux Delay [s]';

            % Create AuxDelaysEditField
            app.AuxDelaysEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.AuxDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @AuxDelaysEditFieldValueChanged, true);
            app.AuxDelaysEditField.Position = [116 9 100 22];

            % Create ShutterDelaysEditFieldLabel
            app.ShutterDelaysEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.ShutterDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.ShutterDelaysEditFieldLabel.Position = [7 44 94 22];
            app.ShutterDelaysEditFieldLabel.Text = 'Shutter Delay [s]';

            % Create ShutterDelaysEditField
            app.ShutterDelaysEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.ShutterDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @ShutterDelaysEditFieldValueChanged, true);
            app.ShutterDelaysEditField.Position = [116 44 100 22];

            % Create NumberofPulsesSpinnerLabel
            app.NumberofPulsesSpinnerLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.NumberofPulsesSpinnerLabel.HorizontalAlignment = 'right';
            app.NumberofPulsesSpinnerLabel.Position = [1 76 101 22];
            app.NumberofPulsesSpinnerLabel.Text = 'Number of Pulses';

            % Create NumberofPulsesSpinner
            app.NumberofPulsesSpinner = uispinner(app.DispersivePulseSettingsPanel);
            app.NumberofPulsesSpinner.ValueChangedFcn = createCallbackFcn(app, @NumberofPulsesSpinnerValueChanged, true);
            app.NumberofPulsesSpinner.Position = [117 76 100 22];

            % Create SamplingSettingsPanel
            app.SamplingSettingsPanel = uipanel(app.SettingsTab);
            app.SamplingSettingsPanel.Title = 'Sampling Settings';
            app.SamplingSettingsPanel.Position = [16 13 245 335];

            % Create SignalAcqDelaysEditFieldLabel
            app.SignalAcqDelaysEditFieldLabel = uilabel(app.SamplingSettingsPanel);
            app.SignalAcqDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.SignalAcqDelaysEditFieldLabel.Position = [-1 285 113 22];
            app.SignalAcqDelaysEditFieldLabel.Text = 'Signal Acq Delay [s]';

            % Create SignalAcqDelaysEditField
            app.SignalAcqDelaysEditField = uieditfield(app.SamplingSettingsPanel, 'numeric');
            app.SignalAcqDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @SignalAcqDelaysEditFieldValueChanged, true);
            app.SignalAcqDelaysEditField.Position = [127 285 100 22];

            % Create SamplesPerPulseSpinnerLabel
            app.SamplesPerPulseSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.SamplesPerPulseSpinnerLabel.HorizontalAlignment = 'right';
            app.SamplesPerPulseSpinnerLabel.Position = [6 216 108 22];
            app.SamplesPerPulseSpinnerLabel.Text = 'Samples Per Pulse';

            % Create SamplesPerPulseSpinner
            app.SamplesPerPulseSpinner = uispinner(app.SamplingSettingsPanel);
            app.SamplesPerPulseSpinner.ValueChangedFcn = createCallbackFcn(app, @SamplesPerPulseSpinnerValueChanged, true);
            app.SamplesPerPulseSpinner.Position = [129 216 100 22];

            % Create Log2OfAvgsSpinnerLabel
            app.Log2OfAvgsSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.Log2OfAvgsSpinnerLabel.HorizontalAlignment = 'right';
            app.Log2OfAvgsSpinnerLabel.Position = [26 182 88 22];
            app.Log2OfAvgsSpinnerLabel.Text = 'Log2 # Of Avgs';

            % Create Log2OfAvgsSpinner
            app.Log2OfAvgsSpinner = uispinner(app.SamplingSettingsPanel);
            app.Log2OfAvgsSpinner.ValueChangedFcn = createCallbackFcn(app, @Log2OfAvgsSpinnerValueChanged, true);
            app.Log2OfAvgsSpinner.Position = [129 182 100 22];

            % Create StartofSummationSpinnerLabel
            app.StartofSummationSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.StartofSummationSpinnerLabel.HorizontalAlignment = 'right';
            app.StartofSummationSpinnerLabel.Position = [6 146 108 22];
            app.StartofSummationSpinnerLabel.Text = 'Start of Summation';

            % Create StartofSummationSpinner
            app.StartofSummationSpinner = uispinner(app.SamplingSettingsPanel);
            app.StartofSummationSpinner.ValueChangedFcn = createCallbackFcn(app, @StartofSummationSpinnerValueChanged, true);
            app.StartofSummationSpinner.Position = [129 146 100 22];

            % Create StartofSubractionSpinnerLabel
            app.StartofSubractionSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.StartofSubractionSpinnerLabel.HorizontalAlignment = 'right';
            app.StartofSubractionSpinnerLabel.Position = [9 111 105 22];
            app.StartofSubractionSpinnerLabel.Text = 'Start of Subraction';

            % Create StartofSubractionSpinner
            app.StartofSubractionSpinner = uispinner(app.SamplingSettingsPanel);
            app.StartofSubractionSpinner.ValueChangedFcn = createCallbackFcn(app, @StartofSubractionSpinnerValueChanged, true);
            app.StartofSubractionSpinner.Position = [129 111 100 22];

            % Create SumSubwidthSpinnerLabel
            app.SumSubwidthSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.SumSubwidthSpinnerLabel.HorizontalAlignment = 'right';
            app.SumSubwidthSpinnerLabel.Position = [28 77 86 22];
            app.SumSubwidthSpinnerLabel.Text = 'Sum/Sub width';

            % Create SumSubwidthSpinner
            app.SumSubwidthSpinner = uispinner(app.SamplingSettingsPanel);
            app.SumSubwidthSpinner.ValueChangedFcn = createCallbackFcn(app, @SumSubwidthSpinnerValueChanged, true);
            app.SumSubwidthSpinner.Position = [129 77 100 22];

            % Create Offset1EditFieldLabel
            app.Offset1EditFieldLabel = uilabel(app.SamplingSettingsPanel);
            app.Offset1EditFieldLabel.HorizontalAlignment = 'right';
            app.Offset1EditFieldLabel.Position = [11 15 47 22];
            app.Offset1EditFieldLabel.Text = 'Offset 1';

            % Create Offset1EditField
            app.Offset1EditField = uieditfield(app.SamplingSettingsPanel, 'numeric');
            app.Offset1EditField.ValueChangedFcn = createCallbackFcn(app, @Offset1EditFieldValueChanged, true);
            app.Offset1EditField.Position = [73 15 38 22];

            % Create Offset2EditFieldLabel
            app.Offset2EditFieldLabel = uilabel(app.SamplingSettingsPanel);
            app.Offset2EditFieldLabel.HorizontalAlignment = 'right';
            app.Offset2EditFieldLabel.Position = [127 15 47 22];
            app.Offset2EditFieldLabel.Text = 'Offset 2';

            % Create Offset2EditField
            app.Offset2EditField = uieditfield(app.SamplingSettingsPanel, 'numeric');
            app.Offset2EditField.ValueChangedFcn = createCallbackFcn(app, @Offset2EditFieldValueChanged, true);
            app.Offset2EditField.Position = [189 15 39 22];

            % Create UsePresetOffsetsCheckBox
            app.UsePresetOffsetsCheckBox = uicheckbox(app.SamplingSettingsPanel);
            app.UsePresetOffsetsCheckBox.ValueChangedFcn = createCallbackFcn(app, @UsePresetOffsetsCheckBoxValueChanged, true);
            app.UsePresetOffsetsCheckBox.Text = 'Use Preset Offsets';
            app.UsePresetOffsetsCheckBox.Position = [62 46 122 22];

            % Create AuxAcqDelaysEditFieldLabel
            app.AuxAcqDelaysEditFieldLabel = uilabel(app.SamplingSettingsPanel);
            app.AuxAcqDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.AuxAcqDelaysEditFieldLabel.Position = [13 252 100 22];
            app.AuxAcqDelaysEditFieldLabel.Text = 'Aux Acq Delay [s]';

            % Create AuxAcqDelaysEditField
            app.AuxAcqDelaysEditField = uieditfield(app.SamplingSettingsPanel, 'numeric');
            app.AuxAcqDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @AuxAcqDelaysEditFieldValueChanged, true);
            app.AuxAcqDelaysEditField.Position = [128 252 100 22];

            % Create FeedbackSettingsPanel
            app.FeedbackSettingsPanel = uipanel(app.SettingsTab);
            app.FeedbackSettingsPanel.Title = 'Feedback Settings';
            app.FeedbackSettingsPanel.Position = [283 145 231 117];

            % Create MaxMWPulsesEditFieldLabel
            app.MaxMWPulsesEditFieldLabel = uilabel(app.FeedbackSettingsPanel);
            app.MaxMWPulsesEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxMWPulsesEditFieldLabel.Position = [7 68 102 22];
            app.MaxMWPulsesEditFieldLabel.Text = 'Max # MW Pulses';

            % Create MaxMWPulsesEditField
            app.MaxMWPulsesEditField = uieditfield(app.FeedbackSettingsPanel, 'numeric');
            app.MaxMWPulsesEditField.ValueChangedFcn = createCallbackFcn(app, @MaxMWPulsesEditFieldValueChanged, true);
            app.MaxMWPulsesEditField.Position = [124 68 100 22];

            % Create TargetSignalEditFieldLabel
            app.TargetSignalEditFieldLabel = uilabel(app.FeedbackSettingsPanel);
            app.TargetSignalEditFieldLabel.HorizontalAlignment = 'right';
            app.TargetSignalEditFieldLabel.Position = [33 37 76 22];
            app.TargetSignalEditFieldLabel.Text = 'Target Signal';

            % Create TargetSignalEditField
            app.TargetSignalEditField = uieditfield(app.FeedbackSettingsPanel, 'numeric');
            app.TargetSignalEditField.ValueChangedFcn = createCallbackFcn(app, @TargetSignalEditFieldValueChanged, true);
            app.TargetSignalEditField.Position = [124 37 100 22];

            % Create SignalToleranceEditFieldLabel
            app.SignalToleranceEditFieldLabel = uilabel(app.FeedbackSettingsPanel);
            app.SignalToleranceEditFieldLabel.HorizontalAlignment = 'right';
            app.SignalToleranceEditFieldLabel.Position = [15 3 94 22];
            app.SignalToleranceEditFieldLabel.Text = 'Signal Tolerance';

            % Create SignalToleranceEditField
            app.SignalToleranceEditField = uieditfield(app.FeedbackSettingsPanel, 'numeric');
            app.SignalToleranceEditField.ValueChangedFcn = createCallbackFcn(app, @SignalToleranceEditFieldValueChanged, true);
            app.SignalToleranceEditField.Position = [124 3 100 22];

            % Create MicrowaveSettingsPanel
            app.MicrowaveSettingsPanel = uipanel(app.SettingsTab);
            app.MicrowaveSettingsPanel.Title = 'Microwave Settings';
            app.MicrowaveSettingsPanel.Position = [270 270 244 122];

            % Create MWPulseWidthsEditFieldLabel
            app.MWPulseWidthsEditFieldLabel = uilabel(app.MicrowaveSettingsPanel);
            app.MWPulseWidthsEditFieldLabel.HorizontalAlignment = 'right';
            app.MWPulseWidthsEditFieldLabel.Position = [12 40 110 22];
            app.MWPulseWidthsEditFieldLabel.Text = 'MW Pulse Width [s]';

            % Create MWPulseWidthsEditField
            app.MWPulseWidthsEditField = uieditfield(app.MicrowaveSettingsPanel, 'numeric');
            app.MWPulseWidthsEditField.ValueChangedFcn = createCallbackFcn(app, @MWPulseWidthsEditFieldValueChanged, true);
            app.MWPulseWidthsEditField.Position = [137 40 100 22];

            % Create MWPulsePeriodsEditFieldLabel
            app.MWPulsePeriodsEditFieldLabel = uilabel(app.MicrowaveSettingsPanel);
            app.MWPulsePeriodsEditFieldLabel.HorizontalAlignment = 'right';
            app.MWPulsePeriodsEditFieldLabel.Position = [8 9 114 22];
            app.MWPulsePeriodsEditFieldLabel.Text = 'MW Pulse Period [s]';

            % Create MWPulsePeriodsEditField
            app.MWPulsePeriodsEditField = uieditfield(app.MicrowaveSettingsPanel, 'numeric');
            app.MWPulsePeriodsEditField.ValueChangedFcn = createCallbackFcn(app, @MWPulsePeriodsEditFieldValueChanged, true);
            app.MWPulsePeriodsEditField.Position = [137 9 100 22];

            % Create ManualMWPulsesSpinnerLabel
            app.ManualMWPulsesSpinnerLabel = uilabel(app.MicrowaveSettingsPanel);
            app.ManualMWPulsesSpinnerLabel.HorizontalAlignment = 'right';
            app.ManualMWPulsesSpinnerLabel.Position = [3 68 119 22];
            app.ManualMWPulsesSpinnerLabel.Text = 'Manual # MW Pulses';

            % Create ManualMWPulsesSpinner
            app.ManualMWPulsesSpinner = uispinner(app.MicrowaveSettingsPanel);
            app.ManualMWPulsesSpinner.ValueChangedFcn = createCallbackFcn(app, @ManualMWPulsesSpinnerValueChanged, true);
            app.ManualMWPulsesSpinner.Position = [137 68 100 22];

            % Create FetchSettingsButton
            app.FetchSettingsButton = uibutton(app.SettingsTab, 'push');
            app.FetchSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @FetchSettingsButtonPushed, true);
            app.FetchSettingsButton.Position = [283 78 100 22];
            app.FetchSettingsButton.Text = 'Fetch Settings';

            % Create UploadSettingsButton
            app.UploadSettingsButton = uibutton(app.SettingsTab, 'push');
            app.UploadSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @UploadSettingsButtonPushed, true);
            app.UploadSettingsButton.Position = [401 78 100 22];
            app.UploadSettingsButton.Text = 'Upload Settings';

            % Create SetDefaultsButton
            app.SetDefaultsButton = uibutton(app.SettingsTab, 'push');
            app.SetDefaultsButton.ButtonPushedFcn = createCallbackFcn(app, @SetDefaultsButtonPushed, true);
            app.SetDefaultsButton.Position = [283 112 100 22];
            app.SetDefaultsButton.Text = 'Set Defaults';

            % Create FetchDataButton
            app.FetchDataButton = uibutton(app.SettingsTab, 'push');
            app.FetchDataButton.ButtonPushedFcn = createCallbackFcn(app, @FetchDataButtonPushed, true);
            app.FetchDataButton.Position = [283 38 100 22];
            app.FetchDataButton.Text = 'Fetch Data';

            % Create ReadonlyPanel
            app.ReadonlyPanel = uipanel(app.SettingsTab);
            app.ReadonlyPanel.Title = 'Read-only';
            app.ReadonlyPanel.Position = [525 355 323 148];

            % Create NumberofSamplesCollectedEditFieldLabel
            app.NumberofSamplesCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofSamplesCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofSamplesCollectedEditFieldLabel.Position = [14 103 187 22];
            app.NumberofSamplesCollectedEditFieldLabel.Text = 'Number of Samples Collected';

            % Create NumberofSamplesCollectedEditField
            app.NumberofSamplesCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofSamplesCollectedEditField.Position = [216 103 101 22];

            % Create NumberofPulsesCollectedEditFieldLabel
            app.NumberofPulsesCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofPulsesCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofPulsesCollectedEditFieldLabel.Position = [25 68 177 22];
            app.NumberofPulsesCollectedEditFieldLabel.Text = 'Number of Pulses Collected';

            % Create NumberofPulsesCollectedEditField
            app.NumberofPulsesCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofPulsesCollectedEditField.Position = [217 68 100 22];

            % Create NumberofAuxPulsesCollectedEditFieldLabel
            app.NumberofAuxPulsesCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofAuxPulsesCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofAuxPulsesCollectedEditFieldLabel.Position = [24 36 178 22];
            app.NumberofAuxPulsesCollectedEditFieldLabel.Text = 'Number of Aux Pulses Collected';

            % Create NumberofAuxPulsesCollectedEditField
            app.NumberofAuxPulsesCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofAuxPulsesCollectedEditField.Position = [217 36 100 22];

            % Create NumberofRatiosCollectedEditFieldLabel
            app.NumberofRatiosCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofRatiosCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofRatiosCollectedEditFieldLabel.Position = [45 3 157 22];
            app.NumberofRatiosCollectedEditFieldLabel.Text = 'Number of Ratios Collected';

            % Create NumberofRatiosCollectedEditField
            app.NumberofRatiosCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofRatiosCollectedEditField.Position = [217 3 100 22];

            % Create ResetButton
            app.ResetButton = uibutton(app.SettingsTab, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [401 38 100 22];
            app.ResetButton.Text = 'Reset';

            % Create StartButton
            app.StartButton = uibutton(app.SettingsTab, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Position = [401 112 100 22];
            app.StartButton.Text = 'Start';

            % Create CalculatedValuesPanel
            app.CalculatedValuesPanel = uipanel(app.SettingsTab);
            app.CalculatedValuesPanel.Title = 'Calculated Values';
            app.CalculatedValuesPanel.Position = [550 511 299 122];

            % Create EffectivesamplerateHzEditFieldLabel
            app.EffectivesamplerateHzEditFieldLabel = uilabel(app.CalculatedValuesPanel);
            app.EffectivesamplerateHzEditFieldLabel.HorizontalAlignment = 'right';
            app.EffectivesamplerateHzEditFieldLabel.Position = [38 72 142 22];
            app.EffectivesamplerateHzEditFieldLabel.Text = 'Effective sample rate [Hz]';

            % Create EffectivesamplerateHzEditField
            app.EffectivesamplerateHzEditField = uieditfield(app.CalculatedValuesPanel, 'numeric');
            app.EffectivesamplerateHzEditField.Position = [195 72 100 22];

            % Create SamplesPulseWidthEditFieldLabel
            app.SamplesPulseWidthEditFieldLabel = uilabel(app.CalculatedValuesPanel);
            app.SamplesPulseWidthEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplesPulseWidthEditFieldLabel.Position = [50 43 130 22];
            app.SamplesPulseWidthEditFieldLabel.Text = '# Samples Pulse Width';

            % Create SamplesPulseWidthEditField
            app.SamplesPulseWidthEditField = uieditfield(app.CalculatedValuesPanel, 'numeric');
            app.SamplesPulseWidthEditField.Position = [195 43 100 22];

            % Create SamplesPulsePeriodEditFieldLabel
            app.SamplesPulsePeriodEditFieldLabel = uilabel(app.CalculatedValuesPanel);
            app.SamplesPulsePeriodEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplesPulsePeriodEditFieldLabel.Position = [46 10 134 22];
            app.SamplesPulsePeriodEditFieldLabel.Text = '# Samples Pulse Period';

            % Create SamplesPulsePeriodEditField
            app.SamplesPulsePeriodEditField = uieditfield(app.CalculatedValuesPanel, 'numeric');
            app.SamplesPulsePeriodEditField.Position = [195 10 100 22];

            % Create ManualOutputsPanel
            app.ManualOutputsPanel = uipanel(app.SettingsTab);
            app.ManualOutputsPanel.Title = 'Manual Outputs';
            app.ManualOutputsPanel.Position = [525 141 136 185];

            % Create UseManualValuesButton
            app.UseManualValuesButton = uibutton(app.ManualOutputsPanel, 'state');
            app.UseManualValuesButton.ValueChangedFcn = createCallbackFcn(app, @UseManualValuesButtonValueChanged, true);
            app.UseManualValuesButton.Text = 'Use Manual Values';
            app.UseManualValuesButton.Position = [6 131 119 22];

            % Create DPPulseButton
            app.DPPulseButton = uibutton(app.ManualOutputsPanel, 'state');
            app.DPPulseButton.ValueChangedFcn = createCallbackFcn(app, @DPPulseButtonValueChanged, true);
            app.DPPulseButton.Text = 'DP Pulse';
            app.DPPulseButton.Position = [6 103 100 22];

            % Create ShutterButton
            app.ShutterButton = uibutton(app.ManualOutputsPanel, 'state');
            app.ShutterButton.ValueChangedFcn = createCallbackFcn(app, @ShutterButtonValueChanged, true);
            app.ShutterButton.Text = 'Shutter';
            app.ShutterButton.Position = [6 72 100 22];

            % Create MWPulseButton
            app.MWPulseButton = uibutton(app.ManualOutputsPanel, 'state');
            app.MWPulseButton.ValueChangedFcn = createCallbackFcn(app, @MWPulseButtonValueChanged, true);
            app.MWPulseButton.Text = 'MW Pulse';
            app.MWPulseButton.Position = [6 42 100 22];

            % Create AuxButton
            app.AuxButton = uibutton(app.ManualOutputsPanel, 'state');
            app.AuxButton.ValueChangedFcn = createCallbackFcn(app, @AuxButtonValueChanged, true);
            app.AuxButton.Text = 'Aux';
            app.AuxButton.Position = [6 10 100 22];

            % Create SignalcomputationPanel
            app.SignalcomputationPanel = uipanel(app.SettingsTab);
            app.SignalcomputationPanel.Title = 'Signal computation';
            app.SignalcomputationPanel.Position = [260 508 250 119];

            % Create UseFixedAuxValuesCheckBox
            app.UseFixedAuxValuesCheckBox = uicheckbox(app.SignalcomputationPanel);
            app.UseFixedAuxValuesCheckBox.ValueChangedFcn = createCallbackFcn(app, @UseFixedAuxValuesCheckBoxValueChanged, true);
            app.UseFixedAuxValuesCheckBox.Text = 'Use Fixed Aux Values';
            app.UseFixedAuxValuesCheckBox.Position = [16 73 139 22];

            % Create Aux1EditFieldLabel
            app.Aux1EditFieldLabel = uilabel(app.SignalcomputationPanel);
            app.Aux1EditFieldLabel.HorizontalAlignment = 'right';
            app.Aux1EditFieldLabel.Position = [21 44 36 22];
            app.Aux1EditFieldLabel.Text = 'Aux 1';

            % Create Aux1EditField
            app.Aux1EditField = uieditfield(app.SignalcomputationPanel, 'numeric');
            app.Aux1EditField.ValueChangedFcn = createCallbackFcn(app, @Aux1EditFieldValueChanged, true);
            app.Aux1EditField.Position = [72 44 100 22];

            % Create Aux2EditFieldLabel
            app.Aux2EditFieldLabel = uilabel(app.SignalcomputationPanel);
            app.Aux2EditFieldLabel.HorizontalAlignment = 'right';
            app.Aux2EditFieldLabel.Position = [21 13 36 22];
            app.Aux2EditFieldLabel.Text = 'Aux 2';

            % Create Aux2EditField
            app.Aux2EditField = uieditfield(app.SignalcomputationPanel, 'numeric');
            app.Aux2EditField.ValueChangedFcn = createCallbackFcn(app, @Aux2EditFieldValueChanged, true);
            app.Aux2EditField.Position = [72 13 100 22];

            % Create ValidationsettingsPanel
            app.ValidationsettingsPanel = uipanel(app.SettingsTab);
            app.ValidationsettingsPanel.Title = 'Validation settings';
            app.ValidationsettingsPanel.Position = [260 410 245 86];

            % Create UseAdditionalPulsesCheckBox
            app.UseAdditionalPulsesCheckBox = uicheckbox(app.ValidationsettingsPanel);
            app.UseAdditionalPulsesCheckBox.ValueChangedFcn = createCallbackFcn(app, @UseAdditionalPulsesCheckBoxValueChanged, true);
            app.UseAdditionalPulsesCheckBox.Text = 'Use Additional Pulses';
            app.UseAdditionalPulsesCheckBox.Position = [10 42 139 22];

            % Create NumAddPulsesEditFieldLabel
            app.NumAddPulsesEditFieldLabel = uilabel(app.ValidationsettingsPanel);
            app.NumAddPulsesEditFieldLabel.HorizontalAlignment = 'right';
            app.NumAddPulsesEditFieldLabel.Position = [10 11 102 22];
            app.NumAddPulsesEditFieldLabel.Text = 'Num. Add. Pulses';

            % Create NumAddPulsesEditField
            app.NumAddPulsesEditField = uieditfield(app.ValidationsettingsPanel, 'numeric');
            app.NumAddPulsesEditField.ValueChangedFcn = createCallbackFcn(app, @NumAddPulsesEditFieldValueChanged, true);
            app.NumAddPulsesEditField.Position = [127 11 100 22];

            % Create RawDataTab
            app.RawDataTab = uitab(app.TabGroup);
            app.RawDataTab.Title = 'Raw Data';

            % Create RawSignalAxes
            app.RawSignalAxes = uiaxes(app.RawDataTab);
            title(app.RawSignalAxes, 'Raw Signal Data')
            xlabel(app.RawSignalAxes, 'X')
            ylabel(app.RawSignalAxes, 'Y')
            app.RawSignalAxes.Position = [0 336 862 307];

            % Create RawAuxAxes
            app.RawAuxAxes = uiaxes(app.RawDataTab);
            title(app.RawAuxAxes, 'Raw Auxiliary Data')
            xlabel(app.RawAuxAxes, 'X')
            ylabel(app.RawAuxAxes, 'Y')
            app.RawAuxAxes.Position = [1 0 861 317];

            % Create SignalTab
            app.SignalTab = uitab(app.TabGroup);
            app.SignalTab.Title = 'Signal';

            % Create IntegratedSignalAxes
            app.IntegratedSignalAxes = uiaxes(app.SignalTab);
            title(app.IntegratedSignalAxes, 'Integrated Signal Data')
            xlabel(app.IntegratedSignalAxes, 'X')
            ylabel(app.IntegratedSignalAxes, 'Y')
            app.IntegratedSignalAxes.Position = [1 294 861 349];

            % Create IntegratedAuxAxes
            app.IntegratedAuxAxes = uiaxes(app.SignalTab);
            title(app.IntegratedAuxAxes, 'Integrated Auxiliary Data')
            xlabel(app.IntegratedAuxAxes, 'X')
            ylabel(app.IntegratedAuxAxes, 'Y')
            app.IntegratedAuxAxes.Position = [1 1 861 294];

            % Create SumandDifferenceTab
            app.SumandDifferenceTab = uitab(app.TabGroup);
            app.SumandDifferenceTab.Title = 'Sum and Difference';

            % Create SumDiffAxes
            app.SumDiffAxes = uiaxes(app.SumandDifferenceTab);
            title(app.SumDiffAxes, 'Sum and Difference')
            xlabel(app.SumDiffAxes, 'X')
            ylabel(app.SumDiffAxes, 'Y')
            app.SumDiffAxes.Position = [1 1 861 642];

            % Create ComputedDataTab
            app.ComputedDataTab = uitab(app.TabGroup);
            app.ComputedDataTab.Title = 'Computed Data';

            % Create ComputedDataAxes
            app.ComputedDataAxes = uiaxes(app.ComputedDataTab);
            title(app.ComputedDataAxes, 'Computed Data')
            xlabel(app.ComputedDataAxes, 'X')
            ylabel(app.ComputedDataAxes, 'Y')
            app.ComputedDataAxes.Position = [1 1 861 641];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AppFeedbackDP_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end