########################
### Import Packages ###
########################

import time
import datetime as dt

import pandas as pd
from IPython.display import display

import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import matplotlib.animation as animation

import tkinter as tk
from tkinter import ttk

import serial
import sys

from uploading import *

###############
### Classes ###
###############

class Serial(serial.Serial) :
    def __init__(self,
            port = 'COM3',
            baudrate = 115200,
            parity = serial.PARITY_NONE,
            stopbits = serial.STOPBITS_ONE,
            bytesize = serial.EIGHTBITS
        ):
        super().__init__(
            port = port,
            baudrate = baudrate,
            parity = parity,
            stopbits = stopbits,
            bytesize = bytesize,
        )

        if self.isOpen() :
            print('Serial Port is Open')
        else:
            print('Serial Port is Closed')

    def close(self) :
        super().close()

class StripChart:
    def __init__(self, master, conn = None, xlim = 1500) :
        self.master = master
        self.conn = conn
        self.fig = plt.figure()

        self.ax = self.fig.add_subplot(111)
        self.ax.set_title('Temperature Strip-Chart')

        self.xlim = xlim
        self.ax.set_xlim(0, self.xlim)
        self.ax.set_xlabel('Samples')

        self.ax.set_ylim(0, 300)
        self.ax.set_ylabel('Temperature (C)')

        self.ax.grid()

        self.line, = self.ax.plot([], [], lw = 2)
        self.current_state = -1
        self.current_val = -273.15
        self.x_data, self.y_data = [], []

        self.data_df = pd.DataFrame(columns = ['Datetime', 'Temperature (C)'])

        self.canvas = FigureCanvasTkAgg(self.fig, master=self.master)
        self.canvas_widget = self.canvas.get_tk_widget()
        self.canvas_widget.grid(row = 0, column = 0)

    def read_serial(self) :
        if self.conn is not None :
            return self.conn.readline().decode('utf-8').strip('\r\n')
        else :
            return None

    def return_state(self, rx_data):
        states = ['S00', 'S01', 'S02', 'S03', 'S04', 'S05']
        if (rx_data in states) :
            return int(rx_data[-1])
        else:
            return -1

    def data_gen(self):
        t = -1
        while True :
            t += 1

            rx_data = self.read_serial()
            if rx_data is not None :
                try :
                    self.current_val = float(rx_data) # Check if Temperature
                    print(f'Current Temperature: {self.current_val}')
                except (TypeError, ValueError, UnicodeDecodeError) :
                    if self.current_state != self.return_state(rx_data) :
                        if self.return_state(rx_data) != -1 :
                            self.current_state = self.return_state(rx_data)
                            print(f'Current State: {self.current_state}')
                            self.ax.set_title('Temperature Strip-Chart - State ' + str(self.current_state))
                        else :
                            print("Error Reading Temperature From Serial Port!")
                finally :
                    val = self.current_val
                current_time = dt.datetime.now()
            yield t, val, current_time

    def run(self, data):
        t, y, current_time = data
        if t > -1 :
            self.x_data.append(t)
            self.y_data.append(y)
            if t > self.xlim :
                self.ax.set_xlim(t - self.xlim, t)
            self.line.set_data(self.x_data, self.y_data)

            new_df = pd.DataFrame({'Datetime': [current_time], 'Temperature': [y]})
            if self.data_df.empty :
                self.data_df = new_df
            else:
                self.data_df = pd.concat([self.data_df, new_df], ignore_index = True, axis = 0)

            self.current_val = y  # Update Current Value
        return self.line

    def start_animation(self, conn):
        self.conn = conn
        self.animation = animation.FuncAnimation(
            fig = self.fig,
            func = self.run,
            frames = self.data_gen,
            blit = False,
            interval = 120,
            repeat = False,
            save_count = 10  # Adjust this value as needed
        )
        self.canvas = FigureCanvasTkAgg(self.fig, master = self.master)
        self.canvas_widget = self.canvas.get_tk_widget()
        self.canvas_widget.grid(row = 0, column = 0)

    def export_csv(self) :
        if not self.data_df.empty :
            csv_df = self.data_df.copy()
            csv_df['Temperature'] = csv_df.groupby('Datetime')['Temperature'].transform('mean')
            csv_df['Datetime'] = csv_df['Datetime'].dt.strftime('%Y-%m-%d %H:%M:%S')
            csv_path = f'''LogBook/N76E003_{csv_df['Datetime'].iloc[0].replace(' ', '_').replace('-', '_').replace(':', '_')}.csv'''
            csv_df.to_csv(csv_path, index = False)

            print(f"Data Exported to {csv_path}\n\nData Preview:\n")
            display(csv_df.head(2))
            upload_to_bucket(F'LogBook/{csv_path}', os.path.join(os.getcwd(), csv_path), 'kys_data_bucket')
            print(f"Data Uploaded to Google Cloud Storage")

class App :
    def __init__(self) :
        self.root = tk.Tk()
        self.root.configure(
            background = 'black',
            padx = 10, pady = 10
        )
        self.root.resizable(False, False)
        self.root.title("Temperature Strip-Chart")
        # Bind Close Function to Window Close Event
        self.root.protocol("WM_DELETE_WINDOW", self.close)

        self.conn = None  # # Initialize Serial Connection to None

        self.paned_window = ttk.PanedWindow(self.root, orient = tk.HORIZONTAL)
        self.paned_window.pack(fill = tk.BOTH, expand = True)

        ####################
        ### Serial Frame ###
        ####################

        self.serial_frame = tk.Frame(self.paned_window, bg = 'lightgrey')

        # Create Serial Frame Widgets
        self.port_label = tk.Label(self.serial_frame, text = "Serial Line : ", bg = 'lightgrey')
        self.port_entry = tk.Entry(self.serial_frame, bg = 'lightblue')

        self.baudrate_label = tk.Label(self.serial_frame, text = "Speed : ", bg = 'lightgrey')
        self.baudrate_entry = tk.Entry(self.serial_frame, bg = 'lightblue')

        self.parity_label = tk.Label(
            self.serial_frame, text = "Parity : ", bg = 'lightgrey'
        )
        self.parity_combobox = ttk.Combobox(
            self.serial_frame,
            values = [
                'PARITY_NONE', 'PARITY_EVEN', 'PARITY_ODD',
                'PARITY_MARK', 'PARITY_SPACE'
            ]
        )
        self.parity_combobox.set('PARITY_NONE')

        self.stopbits_label = tk.Label(
            self.serial_frame, text = "Stop Bits : ", bg = 'lightgrey'
        )
        self.stopbits_combobox = ttk.Combobox(
            self.serial_frame,
            values = ['STOPBITS_ONE', 'STOPBITS_ONE_POINT_FIVE', 'STOPBITS_TWO'],
        )
        self.stopbits_combobox.set('STOPBITS_ONE')

        self.bytesize_label = tk.Label(
            self.serial_frame, text = "Byte Size : ", bg = 'lightgrey'
        )
        self.bytesize_combobox = ttk.Combobox(
            self.serial_frame,
            values = ['FIVEBITS', 'SIXBITS', 'SEVENBITS', 'EIGHTBITS'],
        )
        self.bytesize_combobox.set('EIGHTBITS')

        self.open_button = tk.Button(
            self.serial_frame, text = "Open", command = self.open_serial, bg = 'lightblue',
        )
        # self.send_button = tk.Button(
        #     self.serial_frame,
        #     text = "Send N76E003(C)", command = lambda : self.send_serial(
        #         f'{int(self.strip_chart.current_val*(10**4))}'
        #     ),
        #     bg = 'lightblue'
        # )

        # Position Serial Frame Widgets
        self.port_label.grid(
            row = 0, column = 0,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10, sticky = 'w'
        )
        self.port_entry.grid(
            row = 0, column = 1,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10
        )

        self.baudrate_label.grid(
            row = 1, column = 0,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10, sticky = 'w'
        )
        self.baudrate_entry.grid(
            row = 1, column = 1,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10
        )

        self.parity_label.grid(
            row = 2, column = 0,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10, sticky = 'w'
        )
        self.parity_combobox.grid(
            row = 2, column = 1,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10
        )

        self.stopbits_label.grid(
            row = 3, column = 0,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10, sticky = 'w'
        )
        self.stopbits_combobox.grid(
            row = 3, column = 1,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10
        )

        self.bytesize_label.grid(
            row = 4, column = 0,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10, sticky = 'w'
        )
        self.bytesize_combobox.grid(
            row = 4, column = 1,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10
        )

        self.open_button.grid(
            row = 5, column = 1,
            rowspan = 1, columnspan = 1,
            padx = 10, pady = 10,
            sticky = 'e'
        )
        # self.send_button.grid(
        #     row = 5, column = 1,
        #     rowspan = 1, columnspan = 1,
        #     padx = 10, pady = 10
        # )

        ########################
        ### StripChart Frame ###
        ########################

        self.strip_chart_frame = tk.Frame(self.paned_window, bg = 'grey')

        # Initialize StripChart in the StripChart frame
        self.strip_chart = StripChart(self.strip_chart_frame)
        self.export_csv_button = tk.Button(
            self.root,
            text = "Export to Spreadsheet", command = self.strip_chart.export_csv,
            bg = 'lightblue'
        )
        self.save_button = tk.Button(
            self.root,
            text = "Save Figure", command = self.save_fig,
            bg = 'lightblue'
        )

        # Position StripChart Frame Widgets
        self.save_button.pack(
            padx = 10, pady=10, side = tk.RIGHT
        )
        self.export_csv_button.pack(
            padx = 10, pady = 10, side = tk.RIGHT
        )

        self.paned_window.add(self.serial_frame)
        self.paned_window.add(self.strip_chart_frame)

        self.root.mainloop()

    def close(self) :
        self.strip_chart.export_csv()
        if self.conn is not None :
            self.conn.close()
        self.root.destroy()
        sys.exit()

    def open_serial(self):
        if self.conn is None :  # Check if Serial Connection Already Established
            port = self.port_entry.get()
            baudrate = self.baudrate_entry.get()

            parity = serial.PARITY_EVEN if self.parity_combobox.get() == 'PARITY_EVEN'\
                else serial.PARITY_ODD if self.parity_combobox.get() == 'PARITY_ODD'\
                else serial.PARITY_MARK if self.parity_combobox.get() == 'PARITY_MARK'\
                else serial.PARITY_SPACE if self.parity_combobox.get() == 'PARITY_SPACE'\
                else serial.PARITY_NONE

            stopbits = serial.STOPBITS_ONE_POINT_FIVE if self.stopbits_combobox.get() == 'STOPBITS_ONE_POINT_FIVE'\
                else serial.STOPBITS_TWO if self.stopbits_combobox.get() == 'STOPBITS_TWO'\
                else serial.STOPBITS_ONE

            bytesize = serial.FIVEBITS if self.bytesize_combobox.get() == 'FIVEBITS'\
                else serial.SIXBITS if self.bytesize_combobox.get() == 'SIXBITS'\
                else serial.SEVENBITS if self.bytesize_combobox.get() == 'SEVENBITS'\
                else serial.EIGHTBITS

            try :
                self.conn = Serial(
                    port = port, baudrate = int(baudrate),
                    parity = parity, stopbits = stopbits, bytesize = bytesize
                )

                self.strip_chart.start_animation(conn = self.conn) # Start Animation
            except Exception as e :
                print(f"Error Opening Serial Port\n {e}")

    def save_fig(self) :
        file_path = 'temperature_chart.jpg'
        self.strip_chart.fig.savefig(file_path, format = 'jpg', dpi = 800)
        print(f"Figure Saved As {file_path}")

    def send_serial(self, temp_parsed) :
        if self.conn is not None :
            num_send = len(temp_parsed) // 2

            for i in range(num_send) :
                curr_byte = hex(int(temp_parsed[i*2 : i*2+2]))
                print(f"Sending {curr_byte}")
                self.conn.write(curr_byte.encode('utf-8'))

if __name__ == "__main__":
    app = App()
